import AppRemoteConfig
import Foundation
#if os(iOS) || os(tvOS)
import UIKit
#endif

enum ConfigurationServiceError: Error {
    case unexpectedType
}

class ConfigurationService {
    let url: URL
    let platform: Platform
    let platformVersion: Version
    let appVersion: Version
    let buildVariant: BuildVariant
    let language: String?
    
    private var config: Config?
    
    public init(url: URL) {
        self.url = url
        
#if os(iOS) || os(tvOS)
        let sub: Platform.IOS?
        switch UIDevice.current.userInterfaceIdiom {
        case .unspecified:
            sub = nil
        case .phone:
            sub = .phone
        case .pad:
            sub = .pad
        case .tv:
            sub = .tv
        case .carPlay:
            sub = .carPlay
        case .mac:
            sub = .mac
        case .vision:
            sub = nil
        @unknown default:
            sub = nil
        }
        platform = .iOS(sub)
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
        
        // This is force unwrapped because the included fallback config must parse without issue
        let data = try! Data(contentsOf: bundledURL)
        try! readConfig(from: data)
    }
    
    var bundledURL: URL {
        // This is force unwrapped because the fallback config must be included
        Bundle.main.url(forResource: "config", withExtension: "json")!
    }
    
    var localCacheURL: URL? {
        guard let path = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).first else {
            return nil
        }
        return URL(fileURLWithPath: path + "/config.json")
    }
    
    private func readConfig(from data: Data) throws {
        guard let json = try JSONSerialization.jsonObject(with: data, options: .json5Allowed) as? [String: Any] else {
            throw ConfigurationServiceError.unexpectedType
        }
        config = try Config(json: json)
    }
    
    public func prepare() {
        do {
            if let localCacheURL {
                let data = try Data(contentsOf: localCacheURL)
                try readConfig(from: data)
            }
        } catch {
            // Ignore
        }
    }
    
    public func update() async throws {
//        let (data, response) = try await URLSession.shared.data(from: url)
        let data = demo()
        try readConfig(from: data)
        do {
            if let localCacheURL {
                try data.write(to: localCacheURL)
            } else {
                assertionFailure("Failed to create local cache URL")
            }
        } catch {
            assertionFailure("Failed to cache config data")
        }
    }
    
    public func resolve(date: Date, variant: String? = nil) -> [String: Any] {
        assert(config != nil, "Run prepare() first")
        return config?.resolve(date: date, platform: platform, platformVersion: platformVersion, appVersion: appVersion, buildVariant: buildVariant, language: language) ?? [:]
    }
    
    public func nextResolutionDate(after date: Date, variant: String? = nil) -> Date? {
        assert(config != nil, "Run prepare() first")
        return config?.relevantResolutionDates(platform: platform, platformVersion: platformVersion, appVersion: appVersion, buildVariant: buildVariant, language: language).first(where: { $0.timeIntervalSince(date) > 0 })
    }
    
    func demo() -> Data {
        let jsonString = """
         {
             "settings": {
                 // General
                 "foo": true,
                 "bar": "hello world",
                 "baz": [
                     {
                         "abc": "def"
                     }
                 ],
                 // Update
                 "updateRequired": false,
                 "updateRecommended": false,
                 "appDisabled": false
             },
             "deprecatedKeys": [
                 "old1",
                 "old3"
             ],
             "overrides": [
                 {
                     "schedule": {
                         "from": "2024-01-11T19:35:00Z"
                     },
                     "settings": {
                         "updateRecommended": true
                     }
                 }
             ],
             "meta": {
                 "updated": "2024-01-08T12:00:00Z",
                 // "sequence"
                 "author": "Johan",
                 "client": "Secret Agency"
             }
         }
         """
        return jsonString.data(using: .utf8)!
    }
}
