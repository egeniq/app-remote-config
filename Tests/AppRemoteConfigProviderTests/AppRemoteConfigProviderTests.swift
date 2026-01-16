import Testing
import Foundation
import Configuration
import Crypto
@testable import AppRemoteConfigProvider
@testable import AppRemoteConfig

/// Tests for AppRemoteConfigProvider's swift-configuration Provider integration.
struct AppRemoteConfigProviderTests {
    
    // MARK: - Helper Methods
    
    /// Creates a JSON config file at a temporary URL for testing.
    func createTestConfigFile() throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let configUrl = tempDir.appendingPathComponent("test-config-\(UUID().uuidString).json")
        
        let configJSON: [String: Any] = [
            "settings": [
                "features": [
                    "newUI": true,
                    "betaMode": false
                ],
                "apiEndpoint": "https://api.example.com",
                "timeout": 30
            ],
            "overrides": []
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: configJSON)
        try jsonData.write(to: configUrl)
        
        return configUrl
    }
    
    /// Creates a test config with overrides based on conditions.
    func createTestConfigFileWithOverrides() throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let configUrl = tempDir.appendingPathComponent("test-config-overrides-\(UUID().uuidString).json")
        
        let configJSON: [String: Any] = [
            "settings": [
                "betaMode": false,
                "apiEndpoint": "https://api.example.com"
            ],
            "overrides": [
                [
                    "matching": [
                        [
                            "buildVariant": "debug"
                        ]
                    ],
                    "settings": [
                        "betaMode": true
                    ]
                ]
            ]
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: configJSON)
        try jsonData.write(to: configUrl)
        
        return configUrl
    }
    
    // MARK: - Basic Provider Tests
    
    @Test
    func providerInitializationWithContext() async throws {
        let configUrl = try createTestConfigFile()
        defer { try? FileManager.default.removeItem(at: configUrl) }
        
        let context = AppRemoteConfigProvider<JSONSnapshot>.ResolutionContext(
            platform: .iOS,
            platformVersion: OperatingSystemVersion(majorVersion: 17, minorVersion: 0, patchVersion: 0),
            appVersion: try Version("1.2.0"),
            variant: nil,
            buildVariant: .debug,
            language: nil
        )
        
        let _ = try await AppRemoteConfigProvider<JSONSnapshot>(
            url: configUrl,
            pollInterval: .seconds(60),
            resolutionContext: context
        )
    }
    
    @Test
    func valueResolutionWithContext() async throws {
        let configUrl = try createTestConfigFile()
        defer { try? FileManager.default.removeItem(at: configUrl) }
        
        let context = AppRemoteConfigProvider<JSONSnapshot>.ResolutionContext(
            platform: .iOS,
            platformVersion: OperatingSystemVersion(majorVersion: 17, minorVersion: 0, patchVersion: 0),
            appVersion: try Version("1.2.0"),
            variant: nil,
            buildVariant: .release,
            language: "en"
        )
        
        let provider = try await AppRemoteConfigProvider<JSONSnapshot>(
            url: configUrl,
            pollInterval: .seconds(60),
            resolutionContext: context
        )
        
        // Verify context was set
        #expect(provider.getResolutionContext().platform == .iOS)
        #expect(provider.getResolutionContext().buildVariant == .release)
    }
    
    @Test
    func nestedKeyPathResolution() async throws {
        let configUrl = try createTestConfigFile()
        defer { try? FileManager.default.removeItem(at: configUrl) }
        
        let context = AppRemoteConfigProvider<JSONSnapshot>.ResolutionContext(
            platform: .iOS,
            platformVersion: OperatingSystemVersion(majorVersion: 17, minorVersion: 0, patchVersion: 0),
            appVersion: try Version("1.2.0"),
            variant: nil,
            buildVariant: .release,
            language: "en"
        )
        
        let provider = try await AppRemoteConfigProvider<JSONSnapshot>(
            url: configUrl,
            pollInterval: .seconds(60),
            resolutionContext: context
        )
        
        try await Task.sleep(for: .milliseconds(200))
        
        // Use ConfigReader to read values
        let reader = ConfigReader(provider: provider)
        
        // Verify nested key path resolution works correctly
        let betaMode = reader.bool(forKey: "features.betaMode", default: false)
        let newUI = reader.bool(forKey: "features.newUI", default: true)
        let apiEndpoint = reader.string(forKey: "apiEndpoint", default: "")
        let timeout = reader.int(forKey: "timeout", default: 0)
        
        // Verify values match the test config
        #expect(betaMode == false)
        #expect(newUI == true)
        #expect(apiEndpoint == "https://api.example.com")
        #expect(timeout == 30)
    }
    
    
    // MARK: - ConfigReader Integration Tests
    
    @Test
    func configReaderIntegration() async throws {
        let configUrl = try createTestConfigFile()
        defer { try? FileManager.default.removeItem(at: configUrl) }
        
        let context = AppRemoteConfigProvider<JSONSnapshot>.ResolutionContext(
            platform: .iOS,
            platformVersion: OperatingSystemVersion(majorVersion: 17, minorVersion: 0, patchVersion: 0),
            appVersion: try Version("1.2.0"),
            variant: nil,
            buildVariant: .release,
            language: "en"
        )
        
        let provider = try await AppRemoteConfigProvider<JSONSnapshot>(
            url: configUrl,
            pollInterval: .seconds(60),
            resolutionContext: context
        )
        
        let reader = ConfigReader(provider: provider)
        
//        try await Task.sleep(for: .milliseconds(200))
        
        let featureEnabled = reader.bool(forKey: "features.newUI", default: true)
        #expect(featureEnabled == true)
        
        let apiEndpoint = reader.string(forKey: "apiEndpoint", default: "")
        #expect(apiEndpoint == "https://api.example.com")
        
        let timeout = reader.int(forKey: "timeout", default: 0)
        #expect(timeout == 30)
    }
    
    // MARK: - Signed Config Tests
    
    @Test
    func signedConfigVerification() async throws {
        // Create a private key for signing
        let privateKey = Curve25519.Signing.PrivateKey()
        
        // Create config data - note the test needs the structure to be correct
        let configJSON: [String: Any] = [
            "settings": [
                "signedFeature": true,
                "apiKey": "secret-key-123"
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
        
        // Write signed config to temporary file
        let tempDir = FileManager.default.temporaryDirectory
        let configUrl = tempDir.appendingPathComponent("signed-config-\(UUID().uuidString).json")
        try signedData.write(to: configUrl)
        
        let context = AppRemoteConfigProvider<JSONSnapshot>.ResolutionContext(
            platform: .iOS,
            platformVersion: OperatingSystemVersion(majorVersion: 17, minorVersion: 0, patchVersion: 0),
            appVersion: try Version("1.0.0"),
            variant: nil,
            buildVariant: .release,
            language: nil
        )
        
        // Create provider with public key
        let provider = try await AppRemoteConfigProvider<JSONSnapshot>(
            url: configUrl,
            resolutionContext: context,
            publicKey: privateKey.publicKey
        )
        
        let reader = ConfigReader(provider: provider)
        
        // Verify the config values are accessible
        let signedFeature = reader.bool(forKey: "signedFeature", default: false)
        #expect(signedFeature == true)
        
        let apiKey = reader.string(forKey: "apiKey", default: "")
        #expect(apiKey == "secret-key-123")
    }
    
    @Test
    func signedConfigWithInvalidSignature() async throws {
        // Create a private key for signing
        let privateKey = Curve25519.Signing.PrivateKey()
        
        // Create config data
        let configJSON: [String: Any] = [
            "settings": [
                "signedFeature": true
            ]
        ]
        let configData = try JSONSerialization.data(withJSONObject: configJSON)
        
        // Sign with one key
        let signature = try privateKey.signature(for: configData)
        let signedData = try JSONSerialization.data(
            withJSONObject: [
                Config.dataKey: configData.base64EncodedString(),
                Config.signatureKey: signature.base64EncodedString()
            ],
            options: [.sortedKeys]
        )
        
        // Write signed config to temporary file
        let tempDir = FileManager.default.temporaryDirectory
        let configUrl = tempDir.appendingPathComponent("invalid-signed-config-\(UUID().uuidString).json")
        try signedData.write(to: configUrl)
        
        // Try to verify with a different public key
        let otherPrivateKey = Curve25519.Signing.PrivateKey()
        
        let context = AppRemoteConfigProvider<JSONSnapshot>.ResolutionContext(
            platform: .iOS,
            platformVersion: OperatingSystemVersion(majorVersion: 17, minorVersion: 0, patchVersion: 0),
            appVersion: try Version("1.0.0"),
            variant: nil,
            buildVariant: .release,
            language: nil
        )
        
        // Should throw an error during initialization
        await #expect(throws: ConfigError.invalidSignature) {
            try await AppRemoteConfigProvider<JSONSnapshot>(
                url: configUrl,
                resolutionContext: context,
                publicKey: otherPrivateKey.publicKey
            )
        }
    }
}
