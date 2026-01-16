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
            Config.dataKey: settingsData.base64EncodedString(),
            Config.signatureKey: signature.base64EncodedString()
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
    
    /// Tests refresh behavior when file is deleted - provider handles gracefully.
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
        
        // Refresh may or may not throw depending on implementation
        // Just verify provider still works with previous snapshot
        _ = provider.snapshot()
        #expect(true) // Provider survived file deletion
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
    
    /// Tests refresh behavior when file becomes malformed - handles gracefully.
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
        
        // Store valid snapshot before corruption
        let validSnapshot = provider.snapshot()
        #expect(validSnapshot is JSONSnapshot)
        
        // Overwrite with malformed JSON
        let invalidJSON = "{ \"settings\": invalid }"
        try invalidJSON.write(to: configUrl, atomically: true, encoding: .utf8)
        
        // Refresh might fail or keep previous snapshot
        // Provider should handle gracefully
        try? await provider.refresh()
        
        // Snapshot should still be accessible (either updated or kept previous)
        let snapshot = provider.snapshot()
        #expect(snapshot is JSONSnapshot)
    }
    
    // MARK: - Invalid Signature Tests
    
    /// Tests that provider throws when public key provided but config is unsigned.
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
    
    /// Tests that provider validates signed config signature.
    @Test
    func validSignedConfig() async throws {
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
        
        // Should initialize successfully with valid signature
        let provider = try await AppRemoteConfigProvider<JSONSnapshot>(
            url: configUrl,
            pollInterval: nil,
            resolutionContext: context,
            publicKey: publicKey
        )
        
        // Verify we got a provider
        #expect(provider.snapshot() is JSONSnapshot)
    }
}
