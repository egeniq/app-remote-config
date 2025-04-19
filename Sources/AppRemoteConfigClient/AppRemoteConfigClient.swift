import Dependencies
import Sharing

public protocol AppRemoteConfigClient: Sendable {
    func load<Value: Decodable & Sendable>(
        key: String,
        context _: LoadContext<Value>,
        continuation: LoadContinuation<Value>
    )
    
    func subscribe<Value: Decodable & Sendable>(
        key: String,
        context _: LoadContext<Value>,
        subscriber: SharedSubscriber<Value>
    ) -> SharedSubscription
}

public extension DependencyValues {
    var appRemoteConfig: any AppRemoteConfigClient {
        get { self[AppRemoteConfigClientKey.self] }
        set { self[AppRemoteConfigClientKey.self] = newValue }
    }
}
