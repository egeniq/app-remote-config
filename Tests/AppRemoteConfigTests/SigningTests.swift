import Crypto
import Foundation
import XCTest
@testable import AppRemoteConfig

final class SigningTests: XCTestCase {

    func testVerifying() async throws {
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

        XCTAssertTrue(signedConfig.settings["testing"]! as! Bool)
    }

    func testVerifyingWithIncorrectPublicKey() async throws {
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

        XCTAssertThrowsError(try Config(data: signedData, publicKey: otherPrivateKey.publicKey)) {
            error in
            XCTAssertEqual(error as! ConfigError, ConfigError.invalidSignature)
        }
    }
}
