import Sharing

final class MockAppRemoteConfigClient: AppRemoteConfigClient {
    let config: [String: any Sendable]
    
    init(config: [String: any Sendable]) {
        self.config = config
    }
    
    func load<Value: Decodable & Sendable>(key: String, context _: LoadContext<Value>, continuation: LoadContinuation<Value>) {
        guard let value = config[key] as? Value else {
            continuation.resume(throwing: NotFound())
            return
        }
        continuation.resume(returning: value)
    }
    
    func subscribe<Value: Decodable & Sendable>(
        key: String,
        context _: LoadContext<Value>, subscriber: SharedSubscriber<Value>
    ) -> SharedSubscription {
        return SharedSubscription { }
    }
    
    struct NotFound: Error {}
}
