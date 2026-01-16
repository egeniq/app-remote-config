import Testing
import Foundation
import Crypto
@testable import AppRemoteConfigProvider
@testable import AppRemoteConfig

struct DebugTest {
    @Test
    func testSignedConfigStorage() async throws {
        // Create a private key for signing
        let privateKey = Curve25519.Signing.PrivateKey()
        
        // Create simple config data
        let configJSON: [String: Any] = [
            "settings": [
                "testKey": "testValue"
            ],
            "overrides": []
        ]
        let configData = try JSONSerialization.data(withJSONObject: configJSON)
        
        // Sign the config
        let signature = try privateKey.signature(for: configData)
        let signedData = try JSONSerialization.data(
            withJSONObject: [
                Config.dataKey: configData.base64EncodedString(),
                Config.signatureKey: signature.base64EncodedString()
            ],
            options: [.sortedKeys]
        )
        
        // Verify that we can extract the signed config
        guard let json = try JSONSerialization.jsonObject(with: signedData, options: []) as? [String: Any],
              let encodedConfigData = json[Config.dataKey] as? String,
              let extractedData = Data(base64Encoded: encodedConfigData) else {
            throw NSError(domain: "test", code: -1)
        }
        
        #expect(extractedData == configData)
        
        // Verify we can parse it back
        let parsedJSON = try JSONSerialization.jsonObject(with: extractedData) as? [String: Any]
        #expect(parsedJSON != nil)
        #expect(parsedJSON?["settings"] != nil)
    }
}
