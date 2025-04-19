import Foundation
import Sharing

struct LiveAppRemoteConfigClient: AppRemoteConfigClient {
    let remoteConfig: AppRemoteConfigService
    
    init(
        url: URL,
        publicKey: String?,
        minimumRefreshInterval: TimeInterval,
        automaticRefreshInterval: TimeInterval,
        bundleIdentifier: String,
        verificationHandler: @escaping VerificationHandler
    ) {
        remoteConfig = AppRemoteConfigService(
            url: url,
            publicKey: publicKey,
            minimumRefreshInterval: minimumRefreshInterval,
            automaticRefreshInterval: automaticRefreshInterval,
            bundleIdentifier: bundleIdentifier,
            verificationHandler: verificationHandler
        )
    }
    
    func load<Value: Decodable & Sendable>(key: String, context _: LoadContext<Value>, continuation: LoadContinuation<Value>) {
        Task { @MainActor in
            guard let value = remoteConfig.settings[key] as? Value else {
                continuation.resume(throwing: NotFound())
                return
            }
            continuation.resume(returning: value)
        }
    }
    
    func subscribe<Value: Decodable & Sendable>(
        key: String,
        context _: LoadContext<Value>,
        subscriber: SharedSubscriber<Value>
    ) -> SharedSubscription {
        let token = remoteConfig.subscribe(handler: { settings in
            Task { @MainActor in
                guard let value = settings[key] as? Value else {
                    subscriber.yield(throwing: NotFound())
                    return
                }
                subscriber.yield(value)
            }
        })
        
        return SharedSubscription {
            remoteConfig.unsubscribe(token)
        }
    }
    
    struct NotFound: Error {}
}
