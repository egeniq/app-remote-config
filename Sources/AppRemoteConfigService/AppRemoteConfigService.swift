import AppRemoteConfig
import Dependencies
import DependenciesAdditions
import Foundation
#if os(iOS) || os(tvOS)
import UIKit
#endif

public enum AppRemoteConfigServiceError: Error {
    case unexpectedType
}

public class AppRemoteConfigService {
    let url: URL
    let minimumRefreshInterval: TimeInterval
    let automaticRefreshInterval: TimeInterval
    let includedConfigName: String
    let includedConfigExtension: String
    let apply: (_ settings: [String: Any]) -> ()
    
    let platform: Platform
    let platformVersion: Version
    let appVersion: Version
    let buildVariant: BuildVariant
    let language: String?
    
    private(set) var lastSuccessfullFetch: Date?
    
    private var config: Config!
    
    @Dependency(\.logger["AppRemoteConfigService"]) var logger
    @Dependency(\.date.now) var now
    @Dependency(\.mainQueue) var mainQueue
    
    public init(
        url: URL,
        minimumRefreshInterval: TimeInterval = 60,
        automaticRefreshInterval: TimeInterval = 300,
        includedConfigName: String = "appconfig",
        includedConfigExtension: String = "json",
        apply: @escaping (_ settings: [String: Any]) -> ()
    ) {
        self.url = url
        self.minimumRefreshInterval = minimumRefreshInterval
        self.automaticRefreshInterval = automaticRefreshInterval
        self.includedConfigName = includedConfigName
        self.includedConfigExtension = includedConfigExtension
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
            platform = .iOS_tv
        case .carPlay:
            platform = .iOS_carplay
        case .mac:
            platform = .iOS_mac
        case .vision:
            platform = .visionOS
        @unknown default:
            platform = .unknown
        }
        platformVersion = try! Version(UIDevice.current.systemVersion)
#elseif os(macOS)
        platform = .macOS
        platformVersion = try! Version("1.0.0")
#elseif os(watchOS)
        platform = .watchOS
#elseif os(visionOS)
        platform = .visionOS
#else
        platform = .unknown
#endif
        
        let appVersionString = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        appVersion = try! Version(appVersionString)
#if DEBUG
        buildVariant = .debug
#else
        buildVariant = .release
#endif
        
        if #available(iOS 16, macOS 13, *) {
            language = Locale.current.language.languageCode?.identifier
        } else {
            // Fallback on earlier versions
            language = Locale.current.languageCode
        }
        
        logger.debug("Reading bundled fallback")
        // This is force unwrapped because the included fallback config must parse without issue
        let data = try! Data(contentsOf: bundledURL)
        try! readConfig(from: data)
        
        do {
            if let localCacheURL {
                logger.debug("Reading cache")
                let data = try Data(contentsOf: localCacheURL)
                try readConfig(from: data)
            }
        } catch {
            // Ignore
        }
        
        Task { @MainActor in
            resolveAndApply(date: now)
  
            try await update()
        }
        
        // Trigger update on coming to foreground
        NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: self, queue: .main) { _ in
            Task {
                try await self.update(enteringForeground: true)
            }
        }
    }
    
    var bundledURL: URL {
        // This is force unwrapped because the fallback config must be included
        Bundle.main.url(forResource: includedConfigName, withExtension: includedConfigExtension)!
    }
    
    var localCacheURL: URL? {
        guard let path = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).first else {
            return nil
        }
        return URL(fileURLWithPath: path + "/" + includedConfigName + "." + includedConfigExtension)
    }
    
    private func readConfig(from data: Data) throws {
        guard let json = try JSONSerialization.jsonObject(with: data, options: .json5Allowed) as? [String: Any] else {
            throw AppRemoteConfigServiceError.unexpectedType
        }
        config = try Config(json: json)
    }
    
    public func update(enteringForeground: Bool = false) async throws {
        if let lastSuccessfullFetch {
            guard abs(lastSuccessfullFetch.timeIntervalSinceNow) > minimumRefreshInterval else {
                logger.debug("Skipping updating from remote: minimum refresh interval not met")
                return
            }
            if !enteringForeground {
                guard await UIApplication.shared.applicationState == .background else {
                    logger.debug("Skipping updating from remote: app in background")
                    return
                }
            }
        }
        logger.debug("Updating from remote")
        let (data, _) = try await URLSession.shared.data(from: url)
        try readConfig(from: data)
        lastSuccessfullFetch = now
        await resolveAndApply(date: now)
        do {
            if let localCacheURL {
                try data.write(to: localCacheURL)
            } else {
                assertionFailure("Failed to create local cache URL")
            }
        } catch {
            assertionFailure("Failed to cache config data")
        }
        let nextDate = now.addingTimeInterval(automaticRefreshInterval)
        logger.debug("Next update on date \(nextDate, privacy: .public)")
        mainQueue.schedule(after: .init(.now() + nextDate.timeIntervalSinceNow)) {
            Task {
                try await self.update()
            }
        }
    }
    
    public func resolve(date: Date, variant: String? = nil) -> [String: Any] {
        config?.resolve(date: date, platform: platform, platformVersion: platformVersion, appVersion: appVersion, buildVariant: buildVariant, language: language) ?? [:]
    }
    
    public func nextResolutionDate(after date: Date, variant: String? = nil) -> Date? {
       config?.relevantResolutionDates(platform: platform, platformVersion: platformVersion, appVersion: appVersion, buildVariant: buildVariant, language: language).first(where: { $0.timeIntervalSince(date) > 0 })
    }
    
    @MainActor
    private func resolveAndApply(date: Date) {
        logger.debug("Resolving settings for date \(date, privacy: .public)")
        let settings = resolve(date: date)
        logger.debug("Applying settings \(settings)")
        apply(settings)
        if let nextDate = nextResolutionDate(after: date) {
            logger.debug("Next resolve on date \(nextDate, privacy: .public)")
            mainQueue.schedule(after: .init(.now() + nextDate.timeIntervalSinceNow)) {
                self.resolveAndApply(date: nextDate)
            }
        } else {
            logger.debug("No next resolve needed")
        }
    }

}
