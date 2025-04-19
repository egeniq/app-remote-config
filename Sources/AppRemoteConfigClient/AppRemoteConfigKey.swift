import Foundation
import Dependencies
import Sharing

extension SharedReaderKey {
    static func appRemoteConfig<Value>(_ key: String) -> Self where Self == AppRemoteConfigKey<Value> {
        AppRemoteConfigKey(key: key)
    }
}

public struct AppRemoteConfigKey<Value: Decodable & Sendable>: SharedReaderKey {
    let key: String
    let appRemoteConfig: any AppRemoteConfigClient
    
    init(key: String) {
        self.key = key
        @Dependency(\.appRemoteConfig) var appRemoteConfig
        self.appRemoteConfig = appRemoteConfig
    }
    
    public var id: some Hashable { key }
    
    public func load(context: LoadContext<Value>, continuation: LoadContinuation<Value>) {
        appRemoteConfig.load(key: key, context: context, continuation: continuation)
    }
    
    public func subscribe(
        context: LoadContext<Value>, subscriber: SharedSubscriber<Value>
    ) -> SharedSubscription {
        appRemoteConfig.subscribe(key: key, context: context, subscriber: subscriber)
    }
}



