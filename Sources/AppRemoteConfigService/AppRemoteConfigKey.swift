import AppRemoteConfig
import Dependencies
import Foundation
import Sharing

/* USER INPUT
@AppRemoteConfigValues
final class Values {
    public private(set) var newFeature: Bool = false
    public private(set) var otherFeature: Int = 42
    public private(set) var message: String = "Hello, world!"
    public private(set) var discount: Double = -7.25
    public private(set) var authors: [String] = ["Bob", "Jane", "Bob, Jr."]
    public private(set) var prices: [String: Double] = ["Book": 12.50, "Banana": 10, "Bread": 1.99]
}
*/

enum AppRemoteConfigClientKey: DependencyKey {
    public static let liveValue: any AppRemoteConfigClient = {
        let url = URL(string: "https://www.example.com/config.json")!
        let publicKey: String? = nil
        let minimumRefreshInterval = 30.0
        let automaticRefreshInterval = 300.0
        let bundledConfigURL = Bundle.main.url(forResource: "appconfig", withExtension: "json")
        let bundleIdentifier = Bundle.main.bundleIdentifier ?? "Sample" //"com.egeniq.appremoteconfig"
        let values = Values()
        return NonIsolatedAppRemoteConfigClient(
            url: url,
            minimumRefreshInterval: minimumRefreshInterval,
            automaticRefreshInterval: automaticRefreshInterval,
            bundledConfigURL: bundledConfigURL,
            bundleIdentifier: bundleIdentifier,
            values: values
        )
    }()
}


// MACRO OUTPUT
@MainActor
final class Values: ValuesContainer {
    @Shared(.newFeature) var newFeature
//    @Shared(.appRemoteConfig( "newFeature")) var newFeature = false
    
    func apply(settings: [String: Any]) throws {
        var allKeys = Set(settings.keys)
        var incorrectKeys = Set<String>()
        var missingKeys = Set<String>()

        if let newValue = settings["newFeature"] as? Bool  {
            $newFeature.withLock { $0 = newValue }
            allKeys.remove("newFeature")
        } else {
            $newFeature.withLock { $0 = false }
            if allKeys.contains("newFeature") {
                allKeys.remove("newFeature")
                incorrectKeys.insert("newFeature")
            } else {
                missingKeys.insert("newFeature")
            }
        }
        
        if !allKeys.isEmpty || !incorrectKeys.isEmpty || !missingKeys.isEmpty {
            throw AppRemoteConfigServiceError.keysMismatch(unhandled: allKeys, incorrect: incorrectKeys, missing: missingKeys)
        }
    }
}

extension SharedKey where Self == AppRemoteConfigKey<Bool>.Default {
    static var newFeature: Self {
        Self[.appRemoteConfig("newFeature"), default: false]
    }
}

// SAMPLE USAGE
import SwiftUI

struct MyView: View {
    @SharedReader(.newFeature) var newFeatureReadOnly
    @Shared(.newFeature) var newFeature
    
    var body: some View {
        Text("New feature: \(newFeatureReadOnly)")
        
        Toggle("Enable new feature", isOn: Binding(get: { newFeature
        }, set: { new, transaction in
            $newFeature.withLock { $0 = new }
        }))
    }
}

// CODE

extension SharedKey {
    static func appRemoteConfig<Value>(_ key: String) -> Self where Self == AppRemoteConfigKey<Value> {
        AppRemoteConfigKey(key: key)
    }
}

struct AppRemoteConfigKey<Value: Decodable & Sendable>: SharedKey {
    let key: String
    let appRemoteConfig: any AppRemoteConfigClient
    
    init(key: String) {
        self.key = key
        @Dependency(\.appRemoteConfig) var appRemoteConfig
        self.appRemoteConfig = appRemoteConfig
    }
    
    var id: some Hashable { key }
    
    func load(context: LoadContext<Value>, continuation: LoadContinuation<Value>) {
        appRemoteConfig.load(context: context, continuation: continuation)
    }
    
    func save(_ value: Value, context: Sharing.SaveContext, continuation: Sharing.SaveContinuation) {
        appRemoteConfig.save(value, context: context, continuation: continuation)
    }
    
    func subscribe(
        context: LoadContext<Value>, subscriber: SharedSubscriber<Value>
    ) -> SharedSubscription {
        appRemoteConfig.subscribe(context: context, subscriber: subscriber)
    }
}


protocol AppRemoteConfigClient: Sendable {
    func load<Value>(context _: LoadContext<Value>, continuation: LoadContinuation<Value>)
    func save<Value>(_ value: Value, context: Sharing.SaveContext, continuation: Sharing.SaveContinuation)
    func subscribe<Value>(
        context _: LoadContext<Value>, subscriber: SharedSubscriber<Value>
    ) -> SharedSubscription
}

extension DependencyValues {
    var appRemoteConfig: any AppRemoteConfigClient {
        get { self[AppRemoteConfigClientKey.self] }
        set { self[AppRemoteConfigClientKey.self] = newValue }
    }
}

struct NonIsolatedAppRemoteConfigClient: AppRemoteConfigClient {
    init(
        url: URL,
        publicKey: String? = nil,
        minimumRefreshInterval: TimeInterval,
        automaticRefreshInterval: TimeInterval,
        bundledConfigURL: URL? = nil,
        bundleIdentifier: String,
        values: any ValuesContainer
    ) {
        self.url = url
        self.publicKey = publicKey
        self.minimumRefreshInterval = minimumRefreshInterval
        self.automaticRefreshInterval = automaticRefreshInterval
        self.bundledConfigURL = bundledConfigURL
        self.bundleIdentifier = bundleIdentifier
        self.values = values
    }
    
    let live = LockIsolated<AppRemoteConfigService?>(nil)
    
    let url: URL
    let publicKey: String?
    let minimumRefreshInterval: TimeInterval
    let automaticRefreshInterval: TimeInterval
    let bundledConfigURL: URL?
    let bundleIdentifier: String
    let values: ValuesContainer
    
    private func service() -> AppRemoteConfigService {
        if live.value == nil {
            // Create service
            let service = AppRemoteConfigService(
                url: url,
                publicKey: publicKey,
                minimumRefreshInterval: minimumRefreshInterval,
                automaticRefreshInterval: automaticRefreshInterval,
                bundledConfigURL: bundledConfigURL,
                bundleIdentifier: bundleIdentifier,
                values: values
            )
        }
        return live.value!
    }
    
    func load<Value>(context: LoadContext<Value>, continuation: LoadContinuation<Value>) {
        service().load(context: context, continuation: continuation)
    }
    
    func save<Value>(_ value: Value, context: Sharing.SaveContext, continuation: Sharing.SaveContinuation) {
        service().save(value, context: context, continuation: continuation)
    }
    
    func subscribe<Value>(
        context: LoadContext<Value>, subscriber: SharedSubscriber<Value>
    ) -> SharedSubscription {
        service().subscribe(context: context, subscriber: subscriber)
    }
}



//final class MockRemoteConfig: AppRemoteConfigClient {
//    let config: [String: any Sendable]
//    init(config: [String: any Sendable]) {
//        self.config = config
//    }
//    func fetch<T: Decodable>(
//        key: String,
//        completion: @escaping (Result<T, any Error>) -> Void
//    ) {
//        guard let value = config[key] as? T
//        else {
//            completion(.failure(NotFound()))
//            return
//        }
//        completion(.success(value))
//    }
//    func addUpdateListener<T: Decodable>(
//        key: String,
//        subscriber: @escaping (Result<T, any Error>) -> Void
//    ) -> AnyCancellable {
//        AnyCancellable {}
//    }
//    struct NotFound: Error {}
//}
