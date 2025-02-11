import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
public struct SodiumClient: Sendable {
    public var keyPair: @Sendable () -> (publicKey: String, secretKey: String)?
    public var open: @Sendable (_ signedMessage: Data, _ publicKey: String) -> Data?
    public var sign: @Sendable (_ message: Data, _ secretKey: String) -> Data?
}
 
extension SodiumClient: TestDependencyKey{
    public static let testValue = SodiumClient()
}

extension DependencyValues {
    public var sodiumClient: SodiumClient {
        get { self[SodiumClient.self] }
        set { self[SodiumClient.self] = newValue }
    }
}
