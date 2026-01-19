import Crypto
import Foundation
import Testing
@testable import AppRemoteConfig

struct SigningTests {

    @Test
    func verifying() async throws {
        let privateKey = Curve25519.Signing.PrivateKey()
        let configData = """
            {"settings": {"testing": true}}
            """.data(using: .utf8)!
        let signature = try privateKey.signature(for: configData)
        let signedData = try JSONSerialization.data(
            withJSONObject: [
                Config.dataKey: configData.base64EncodedString(),
                Config.signatureKey: signature.base64EncodedString()
            ],
            options: [.sortedKeys]
        )
        
        let signedConfig = try Config(data: signedData, publicKey: privateKey.publicKey)

        #expect(signedConfig.settings["testing"]! as! Bool)
    }

    @Test
    func verifyingWithIncorrectPublicKey() async throws {
        let privateKey = Curve25519.Signing.PrivateKey()
        let configData = """
            {"settings": {"testing": true}}
            """.data(using: .utf8)!
        let signature = try privateKey.signature(for: configData)
        let signedData = try JSONSerialization.data(
            withJSONObject: [
                Config.dataKey: configData.base64EncodedString(),
                Config.signatureKey: signature.base64EncodedString()
            ],
            options: [.sortedKeys]
        )
        let otherPrivateKey = Curve25519.Signing.PrivateKey()

        #expect(throws: ConfigError.self) {
            try Config(data: signedData, publicKey: otherPrivateKey.publicKey)
        }
    }
}
