import AppRemoteConfig
import Combine
import Crypto
import Dependencies
public import Foundation
#if Logging
import Logging
#endif
#if canImport(UIKit)
import UIKit
#endif

public enum AppRemoteConfigServiceError: Error {
    case unexpectedType
    case invalidPublicKey
    case keysMismatch(unhandled: Set<String>, incorrect: Set<String>, missing: Set<String>)
}

/// A service to fetch a remote config from a URL periodically and when the app returns to the foreground.
public final class AppRemoteConfigService: Sendable {
    let url: URL
    let publicKey: String?
    let minimumRefreshInterval: TimeInterval
    let automaticRefreshInterval: TimeInterval
    let bundledConfigURL: URL?
    let bundleIdentifier: String
    let apply: @Sendable @MainActor (_ settings: [String: any Sendable]) throws -> ()
    
    let platform: Platform
    let platformVersion: OperatingSystemVersion
    let appVersion: Version
    let buildVariant: BuildVariant
    let language: String?

#if Logging
    let logger = Logger(label: "app-remote-config.Service")
#endif

    @MainActor
    private(set) var lastSuccessfullFetch: Date?
    
    @MainActor
    private var config: Config!
    
    /// Initializes service
    /// - Parameters:
    ///   - url: URL to remote config.
    ///   - publicKey: Provide the public key that is used for signing the config. Use `nil` for an unsigned config.
    ///   - minimumRefreshInterval: The minimum time interval between refreshes.
    ///   - automaticRefreshInterval: The interval used between refreshes while the app is in the foreground.
    ///   - bundledConfigURL: URL to fallback configuration included in the app in case remote URL is unavailable and not cached.
    ///   - bundleIdentifier: Bundle identifier, recommended value is `Bundle.main.bundleIdentifier`
    ///   - apply: Method called with resolved settings for the app to use.
    @MainActor
    public init(
        url: URL,
        publicKey: String?,
        minimumRefreshInterval: TimeInterval = 60,
        automaticRefreshInterval: TimeInterval = 300,
        bundledConfigURL: URL? = nil,
        bundleIdentifier: String,
        apply: @escaping @Sendable @MainActor (_ settings: [String: any Sendable]) throws -> ()
    ) {
        self.url = url
        self.publicKey = publicKey
        self.minimumRefreshInterval = minimumRefreshInterval
        self.automaticRefreshInterval = automaticRefreshInterval
        self.bundledConfigURL = bundledConfigURL
        self.bundleIdentifier = bundleIdentifier
        self.apply = apply
        
#if os(iOS) || os(tvOS)
        switch UIDevice.current.userInterfaceIdiom {
        case .unspecified:
            platform = .iOS
        case .phone:
            platform = .iOS_iPhone
        case .pad:
            platform = .iOS_iPad
        case .tv:
            platform = .tvOS
        case .carPlay:
            platform = .iOS_carplay
        case .mac:
            platform = .iOS_mac
        case .vision:
            platform = .visionOS
        @unknown default:
            platform = .unknown
        }
#elseif os(macOS)
        platform = .macOS
#elseif os(watchOS)
        platform = .watchOS
#elseif os(visionOS)
        platform = .visionOS
#elseif os(Linux)
        platform = .linux
#elseif os(Android)
        platform = .android
#else
        platform = .unknown
#endif
        platformVersion = ProcessInfo().operatingSystemVersion
        
        let appVersionString = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        appVersion = try! Version(appVersionString)
#if DEBUG
        buildVariant = .debug
#else
        buildVariant = .release
#endif
        
        if #available(iOS 16, macOS 13, tvOS 16, watchOS 9, *) {
            language = Locale.current.language.languageCode?.identifier
        } else {
            // Fallback on earlier versions
            language = Locale.current.languageCode
        }
        
        if let bundledConfigURL {
            log(.debug, "Reading bundled fallback")
            // This is force unwrapped because the included fallback config must parse without issue
            let data = try! Data(contentsOf: bundledConfigURL)
            try! readConfig(from: data)
        } else {
            log(.debug, "No bundled config provided")
        }
        
        do {
            if let localCacheURL {
                log(.debug, "Reading cache")
                let data = try Data(contentsOf: localCacheURL)
                try readConfig(from: data)
            }
        } catch {
            // Ignore
        }
        
        Task {
            @Dependency(\.date.now) var now
            resolveAndApply(date: now)
  
            do {
                try await update()
            } catch {
                log(.error, "Updating failed \(error)")
            }
        }
        
#if os(iOS) || os(tvOS)
        // Trigger update on coming to foreground
        NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: self, queue: .main) { [weak self] _ in
            guard let self else { return }
            Task {
                do {
                    try await self.update(enteringForeground: true)
                } catch {
                    logger.error("Updating failed \(error)")
                }
            }
        }
#endif
    }
    
    var localCacheFolderURL: URL? {
        guard let path = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).first else {
            return nil
        }
        return URL(fileURLWithPath: path + "/" + bundleIdentifier + "/")
    }
    
    var localCacheURL: URL? {
        guard let path = localCacheFolderURL?.relativePath else {
            return nil
        }
        return URL(fileURLWithPath: path + "/appremoteconfig.json")
    }
    
    @MainActor
    private func readConfig(from data: Data) throws {
        if let publicKey {
            guard let publicKeyData = Data(base64Encoded: publicKey) else {
                throw AppRemoteConfigServiceError.invalidPublicKey
            }
            let publicKey = try Curve25519.Signing.PublicKey(rawRepresentation: publicKeyData)
            config = try Config(data: data, publicKey: publicKey)
        } else {
            config = try Config(data: data)
        }
    }
    
    /// Trigger a refresh
    /// - Parameter enteringForeground: Indicate wether the app is entering the foreground
    @MainActor
    public func update(enteringForeground: Bool = false) async throws {
        @Dependency(\.date.now) var now
        if let lastSuccessfullFetch {
            guard abs(lastSuccessfullFetch.timeIntervalSinceNow) > minimumRefreshInterval else {
                log(.debug, "Skipping updating from remote: minimum refresh interval not met")
                return
            }
            if !enteringForeground {
#if os(iOS) || os(tvOS)
                guard UIApplication.shared.applicationState == .background else {
                    log(.debug, "Skipping updating from remote: app in background")
                    return
                }
#endif
            }
        }
        log(.debug, "Updating from remote")
        let (data, _) = try await URLSession.shared.data(from: url)
        try readConfig(from: data)
        lastSuccessfullFetch = now
        resolveAndApply(date: now)
        do {
            if let localCacheFolderURL, let localCacheURL {
                log(.debug, "Writing cache to \(localCacheURL)")
                try FileManager.default.createDirectory(at: localCacheFolderURL, withIntermediateDirectories: true)
                try data.write(to: localCacheURL)
            } else {
                assertionFailure("Failed to create local cache URL")
            }
        } catch {
            assertionFailure("Failed to cache config data")
        }
        let nextDate = now.addingTimeInterval(automaticRefreshInterval)
        log(.debug, "Next update on date \(nextDate)")
        @Dependency(\.mainQueue) var mainQueue
        mainQueue.schedule(after: .init(.now() + nextDate.timeIntervalSinceNow)) {
            Task {
                do {
                    try await self.update()
                } catch {
                    self.log(.error, "Updating failed \(error)")
                }
            }
        }
    }
    
    /// Resolves which settings should be used by an app within its context
    /// - Parameters:
    ///   - date: The date at which the settings are used
    ///   - variant: The variant of the app that runs
    /// - Returns: Resolved settings
    @MainActor
    public func resolve(date: Date, variant: String? = nil) -> [String: any Sendable] {
        config?.resolve(date: date, platform: platform, platformVersion: platformVersion, appVersion: appVersion, buildVariant: buildVariant, language: language) ?? [:]
    }
    
    /// Lists all dates on which resolving the config could give other settings
    /// - Parameters:
    ///   - date: The date at which the settings are used
    ///   - variant: The variant of the app that runs
    /// - Returns: List of relevant dates
    @MainActor
    public func nextResolutionDate(after date: Date, variant: String? = nil) -> Date? {
       config?.relevantResolutionDates(platform: platform, platformVersion: platformVersion, appVersion: appVersion, buildVariant: buildVariant, language: language).first(where: { $0.timeIntervalSince(date) > 0 })
    }
    
    @MainActor
    private func resolveAndApply(date: Date) {
        log(.debug, "Resolving settings for date \(date)")
        let settings = resolve(date: date)
        log(.debug, "Applying settings \(settings)")
        do {
            try apply(settings)
        } catch  {
            switch error {
            case let AppRemoteConfigServiceError.keysMismatch(unhandledKeys, incorrectKeys, missingKeys):
                if !unhandledKeys.isEmpty {
                    log(.warning, "The key(s) \(unhandledKeys.joined(separator: ", ")) were provided but ignored.")
                }
                
                if !incorrectKeys.isEmpty {
                    log(.error, "The key(s) \(incorrectKeys.joined(separator: ", ")) were provided but had unexpected value types.")
                }
                
                if !missingKeys.isEmpty {
                    log(.warning, "The key(s) \(missingKeys.joined(separator: ", ")) were not provided but expected.")
                }
            default:
                log(.error, "Error encounted applying settings: \(error)")
            }
        }
        if let nextDate = nextResolutionDate(after: date) {
            log(.debug, "Next resolve on date \(nextDate)")
            @Dependency(\.mainQueue) var mainQueue
            mainQueue.schedule(after: .init(.now() + nextDate.timeIntervalSinceNow)) {
                self.resolveAndApply(date: nextDate)
            }
        } else {
            log(.debug, "No next resolve needed")
        }
    }


    enum LogLevel {
        case debug
        case warning
        case error
    }

    private func log(_ level: LogLevel, _ message: String) {
        #if Logging
        switch level {
        case .debug:
            logger.debug(Logger.Message(stringLiteral: message))
        case .warning:
            logger.warning(Logger.Message(stringLiteral: message))
        case .error:
            logger.error(Logger.Message(stringLiteral: message))
        }
        #endif
    }
}
