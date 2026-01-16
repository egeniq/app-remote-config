import Testing
import Foundation
import Configuration
import Crypto
@testable import AppRemoteConfigProvider
@testable import AppRemoteConfig

/// Tests for AppRemoteConfigProvider's error handling behavior.
struct AppRemoteConfigProviderErrorTests {
    
    // MARK: - Helper Methods
    
    /// Creates a valid JSON config file at a temporary URL.
    func createTestConfigFile() throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let configUrl = tempDir.appendingPathComponent("test-error-config-\(UUID().uuidString).json")
        
        let configJSON: [String: Any] = [
            "settings": [
                "feature": true
            ],
            "overrides": []
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: configJSON)
        try jsonData.write(to: configUrl)
        
        return configUrl
    }
    
    /// Creates a malformed JSON file that will fail to parse.
    func createMalformedConfigFile() throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let configUrl = tempDir.appendingPathComponent("test-malformed-\(UUID().uuidString).json")
        
        let invalidJSON = "{ \"settings\": { \"feature\": true }" // Missing closing brace
        try invalidJSON.write(to: configUrl, atomically: true, encoding: .utf8)
        
        return configUrl
    }
    
    /// Creates a signed config with valid signature.
    func createSignedConfig(privateKey: Curve25519.Signing.PrivateKey) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let configUrl = tempDir.appendingPathComponent("test-signed-\(UUID().uuidString).json")
        
        let settings: [String: Any] = ["signedFeature": true]
        let settingsData = try JSONSerialization.data(withJSONObject: settings)
        
        let signature = try privateKey.signature(for: settingsData)
        
        let configJSON: [String: Any] = [
            "settings": settings,
            "overrides": [],
            "signature": signature.base64EncodedString()
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: configJSON)
        try jsonData.write(to: configUrl)
        
        return configUrl
    }
    
    /// Creates a signed config with invalid signature.
    func createInvalidSignedConfig() throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let configUrl = tempDir.appendingPathComponent("test-invalid-signed-\(UUID().uuidString).json")
        
        let settings: [String: Any] = ["signedFeature": true]
        let invalidSignature = "INVALID_SIGNATURE_DATA_HERE"
        
        let configJSON: [String: Any] = [
            "settings": settings,
            "overrides": [],
            "signature": invalidSignature
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: configJSON)
        try jsonData.write(to: configUrl)
        
        return configUrl
    }
    
    // MARK: - File Not Found Tests
    
    /// Tests that provider throws when config file doesn't exist.
    @Test
    func fileNotFoundOnInitialization() async throws {
        let nonExistentUrl = URL(fileURLWithPath: "/tmp/nonexistent-\(UUID().uuidString).json")
        
        let context = AppRemoteConfigProvider<JSONSnapshot>.ResolutionContext(
            platform: .iOS,
            platformVersion: OperatingSystemVersion(majorVersion: 17, minorVersion: 0, patchVersion: 0),
            appVersion: try Version("1.0.0"),
            variant: nil,
            buildVariant: .release,
            language: nil
        )
        
        await #expect(throws: Error.self) {
            let _ = try await AppRemoteConfigProvider<JSONSnapshot>(
                url: nonExistentUrl,
                pollInterval: nil,
                resolutionContext: context
            )
        }
    }
    
    /// Tests refresh behavior when file is deleted.
    @Test
    func fileDeletedAfterInitialization() async throws {
        let configUrl = try createTestConfigFile()
        
        let context = AppRemoteConfigProvider<JSONSnapshot>.ResolutionContext(
            platform: .iOS,
            platformVersion: OperatingSystemVersion(majorVersion: 17, minorVersion: 0, patchVersion: 0),
            appVersion: try Version("1.0.0"),
            variant: nil,
            buildVariant: .release,
            language: nil
        )
        
        let provider = try await AppRemoteConfigProvider<JSONSnapshot>(
            url: configUrl,
            pollInterval: nil,
            resolutionContext: context
        )
        
        // Delete the file
        try FileManager.default.removeItem(at: configUrl)
        
        // Refresh should throw
        await #expect(throws: Error.self) {
            try await provider.refresh()
        }
    }
    
    // MARK: - Malformed JSON Tests
    
    /// Tests that provider throws when config contains malformed JSON.
    @Test
    func malformedJSONOnInitialization() async throws {
        let configUrl = try createMalformedConfigFile()
        defer { try? FileManager.default.removeItem(at: configUrl) }
        
        let context = AppRemoteConfigProvider<JSONSnapshot>.ResolutionContext(
            platform: .iOS,
            platformVersion: OperatingSystemVersion(majorVersion: 17, minorVersion: 0, patchVersion: 0),
            appVersion: try Version("1.0.0"),
            variant: nil,
            buildVariant: .release,
            language: nil
        )
        
        await #expect(throws: Error.self) {
            let _ = try await AppRemoteConfigProvider<JSONSnapshot>(
                url: configUrl,
                pollInterval: nil,
                resolutionContext: context
            )
        }
    }
    
    /// Tests refresh behavior when file becomes malformed.
    @Test
    func malformedJSONAfterRefresh() async throws {
        let configUrl = try createTestConfigFile()
        defer { try? FileManager.default.removeItem(at: configUrl) }
        
        let context = AppRemoteConfigProvider<JSONSnapshot>.ResolutionContext(
            platform: .iOS,
            platformVersion: OperatingSystemVersion(majorVersion: 17, minorVersion: 0, patchVersion: 0),
            appVersion: try Version("1.0.0"),
            variant: nil,
            buildVariant: .release,
            language: nil
        )
        
        let provider = try await AppRemoteConfigProvider<JSONSnapshot>(
            url: configUrl,
            pollInterval: nil,
            resolutionContext: context
        )
        
        // Overwrite with malformed JSON
        let invalidJSON = "{ \"settings\": invalid }"
        try invalidJSON.write(to: configUrl, atomically: true, encoding: .utf8)
        
        // Refresh should throw
        await #expect(throws: Error.self) {
            try await provider.refresh()
        }
    }
    
    // MARK: - Invalid Signature Tests
    
    /// Tests that provider throws when signature verification fails.
    @Test
    func invalidSignatureOnInitialization() async throws {
        let configUrl = try createInvalidSignedConfig()
        defer { try? FileManager.default.removeItem(at: configUrl) }
        
        let privateKey = Curve25519.Signing.PrivateKey()
        let publicKey = privateKey.publicKey
        
        let context = AppRemoteConfigProvider<JSONSnapshot>.ResolutionContext(
            platform: .iOS,
            platformVersion: OperatingSystemVersion(majorVersion: 17, minorVersion: 0, patchVersion: 0),
            appVersion: try Version("1.0.0"),
            variant: nil,
            buildVariant: .release,
            language: nil
        )
        
        await #expect(throws: Error.self) {
            let _ = try await AppRemoteConfigProvider<JSONSnapshot>(
                url: configUrl,
                pollInterval: nil,
                resolutionContext: context,
                publicKey: publicKey
            )
        }
    }
    
    /// Tests that provider throws when signature doesn't match content.
    @Test
    func tamperedConfigSignature() async throws {
        let privateKey = Curve25519.Signing.PrivateKey()
        let publicKey = privateKey.publicKey
        
        let configUrl = try createSignedConfig(privateKey: privateKey)
        defer { try? FileManager.default.removeItem(at: configUrl) }
        
        let context = AppRemoteConfigProvider<JSONSnapshot>.ResolutionContext(
            platform: .iOS,
            platformVersion: OperatingSystemVersion(majorVersion: 17, minorVersion: 0, patchVersion: 0),
            appVersion: try Version("1.0.0"),
            variant: nil,
            buildVariant: .release,
            language: nil
        )
        
        // Provider should initialize successfully with valid signature
        let provider = try await AppRemoteConfigProvider<JSONSnapshot>(
            url: configUrl,
            pollInterval: nil,
            resolutionContext: context,
            publicKey: publicKey
        )
        
        // Now tamper with the config but keep the old signature
        let data = try Data(contentsOf: configUrl)
        var json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        var settings = json["settings"] as! [String: Any]
        settings["signedFeature"] = false // Tamper with content
        json["settings"] = settings
        // Keep the old signature - it won't match the new content
        
        let tamperedData = try JSONSerialization.data(withJSONObject: json)
        try tamperedData.write(to: configUrl)
        
        // Refresh should throw due to signature mismatch
        await #expect(throws: Error.self) {
            try await provider.refresh()
        }
    }
    
    /// Tests that unsigned config is rejected when public key is provided.
    @Test
    func unsignedConfigWithPublicKey() async throws {
        let configUrl = try createTestConfigFile() // Unsigned config
        defer { try? FileManager.default.removeItem(at: configUrl) }
        
        let privateKey = Curve25519.Signing.PrivateKey()
        let publicKey = privateKey.publicKey
        
        let context = AppRemoteConfigProvider<JSONSnapshot>.ResolutionContext(
            platform: .iOS,
            platformVersion: OperatingSystemVersion(majorVersion: 17, minorVersion: 0, patchVersion: 0),
            appVersion: try Version("1.0.0"),
            variant: nil,
            buildVariant: .release,
            language: nil
        )
        
        // Should throw because config is unsigned but public key is provided
        await #expect(throws: Error.self) {
            let _ = try await AppRemoteConfigProvider<JSONSnapshot>(
                url: configUrl,
                pollInterval: nil,
                resolutionContext: context,
                publicKey: publicKey
            )
        }
    }
    
    // MARK: - Network Error Tests (for remote URLs)
    
    /// Tests refresh behavior when network URL becomes unreachable.
    @Test
    func networkURLUnreachable() async throws {
        // Use a valid local file for initialization
        let localUrl = try createTestConfigFile()
        defer { try? FileManager.default.removeItem(at: localUrl) }
        
        let context = AppRemoteConfigProvider<JSONSnapshot>.ResolutionContext(
            platform: .iOS,
            platformVersion: OperatingSystemVersion(majorVersion: 17, minorVersion: 0, patchVersion: 0),
            appVersion: try Version("1.0.0"),
            variant: nil,
            buildVariant: .release,
            language: nil
        )
        
        var provider = try await AppRemoteConfigProvider<JSONSnapshot>(
            url: localUrl,
            pollInterval: nil,
            resolutionContext: context
        )
        
        // Change URL to an unreachable network URL
        provider = try await AppRemoteConfigProvider<JSONSnapshot>(
            url: URL(string: "https://nonexistent-domain-12345.invalid/config.json")!,
            pollInterval: nil,
            resolutionContext: context,
            session: URLSession.shared
        )
        
        // Refresh should throw a network error
        await #expect(throws: Error.self) {
            try await provider.refresh()
        }
    }
}
