import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
public struct SodiumClient: TestDependencyKey {
    public var keyPair: () -> (publicKey: String, secretKey: String)?
    public var open: (_ signedMessage: Data, _ publicKey: String) -> Data?
    public var sign: (_ message: Data, _ secretKey: String) -> Data?
    
    public static let testValue = SodiumClient()
}

extension DependencyValues {
  public var sodiumClient: SodiumClient {
    get { self[SodiumClient.self] }
    set { self[SodiumClient.self] = newValue }
  }
}
