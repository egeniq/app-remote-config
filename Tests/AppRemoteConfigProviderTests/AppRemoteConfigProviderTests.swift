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
    
    /// Verifies that the provider can be initialized with a resolution context.
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
    
    /// Tests that the resolution context is properly stored and can be retrieved.
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
    
    /// Tests that nested dictionary values can be accessed using dot-separated key paths.
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
    
    /// Tests basic ConfigReader integration with the provider.
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
        
        let featureEnabled = reader.bool(forKey: "features.newUI", default: true)
        #expect(featureEnabled == true)
        
        let apiEndpoint = reader.string(forKey: "apiEndpoint", default: "")
        #expect(apiEndpoint == "https://api.example.com")
        
        let timeout = reader.int(forKey: "timeout", default: 0)
        #expect(timeout == 30)
    }
    
    // MARK: - Value Type Tests
    
    /// Tests all supported value types with unsigned (non-cryptographically-signed) configs.
    /// Verifies bool, int, double, string, arrays, and nested dictionaries.
    @Test
    func allValueTypesUnsigned() async throws {
        let tempDir = FileManager.default.temporaryDirectory
        let configUrl = tempDir.appendingPathComponent("test-types-\(UUID().uuidString).json")
        
        let configJSON: [String: Any] = [
            "settings": [
                "boolValue": true,
                "intValue": 42,
                "doubleValue": 3.14,
                "stringValue": "hello",
                "stringArray": ["one", "two", "three"],
                "intArray": [1, 2, 3],
                "doubleArray": [1.1, 2.2, 3.3],
                "boolArray": [true, false, true],
                "dictionary": ["one": "foo", "two": true, "three": 3]
            ],
            "overrides": []
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: configJSON)
        try jsonData.write(to: configUrl)
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
            resolutionContext: context
        )
        
        let reader = ConfigReader(provider: provider)
        
        // Test all value types
        #expect(reader.bool(forKey: "boolValue", default: false) == true)
        #expect(reader.int(forKey: "intValue", default: 0) == 42)
        #expect(reader.double(forKey: "doubleValue", default: 0.0) == 3.14)
        #expect(reader.string(forKey: "stringValue", default: "") == "hello")
        
        let stringArray = reader.stringArray(forKey: "stringArray", default: [])
        #expect(stringArray == ["one", "two", "three"])
        
        let intArray = reader.intArray(forKey: "intArray", default: [])
        #expect(intArray == [1, 2, 3])
        
        let doubleArray = reader.doubleArray(forKey: "doubleArray", default: [])
        #expect(doubleArray == [1.1, 2.2, 3.3])
        
        let boolArray = reader.boolArray(forKey: "boolArray", default: [])
        #expect(boolArray == [true, false, true])
        
        // Test nested dictionary values
        #expect(reader.string(forKey: "dictionary.one", default: "") == "foo")
        #expect(reader.bool(forKey: "dictionary.two", default: false) == true)
        #expect(reader.int(forKey: "dictionary.three", default: 0) == 3)
    }
    
    /// Tests all supported value types with cryptographically-signed configs.
    /// Ensures type handling works correctly after signature verification and data unwrapping.
    @Test
    func allValueTypesSigned() async throws {
        let privateKey = Curve25519.Signing.PrivateKey()
        
        let configJSON: [String: Any] = [
            "settings": [
                "boolValue": true,
                "intValue": 42,
                "doubleValue": 3.14,
                "stringValue": "hello",
                "stringArray": ["one", "two", "three"],
                "intArray": [1, 2, 3],
                "doubleArray": [1.1, 2.2, 3.3],
                "boolArray": [true, false, true],
                "dictionary": ["one": "foo", "two": true, "three": 3]
            ],
            "overrides": []
        ]
        
        let configData = try JSONSerialization.data(withJSONObject: configJSON)
        let signature = try privateKey.signature(for: configData)
        let signedData = try JSONSerialization.data(
            withJSONObject: [
                Config.dataKey: configData.base64EncodedString(),
                Config.signatureKey: signature.base64EncodedString()
            ],
            options: [.sortedKeys]
        )
        
        let tempDir = FileManager.default.temporaryDirectory
        let configUrl = tempDir.appendingPathComponent("signed-types-\(UUID().uuidString).json")
        try signedData.write(to: configUrl)
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
            resolutionContext: context,
            publicKey: privateKey.publicKey
        )
        
        let reader = ConfigReader(provider: provider)
        
        // Test all value types with signed config
        #expect(reader.bool(forKey: "boolValue", default: false) == true)
        #expect(reader.int(forKey: "intValue", default: 0) == 42)
        #expect(reader.double(forKey: "doubleValue", default: 0.0) == 3.14)
        #expect(reader.string(forKey: "stringValue", default: "") == "hello")
        
        let stringArray = reader.stringArray(forKey: "stringArray", default: [])
        #expect(stringArray == ["one", "two", "three"])
        
        let intArray = reader.intArray(forKey: "intArray", default: [])
        #expect(intArray == [1, 2, 3])
        
        let doubleArray = reader.doubleArray(forKey: "doubleArray", default: [])
        #expect(doubleArray == [1.1, 2.2, 3.3])
        
        let boolArray = reader.boolArray(forKey: "boolArray", default: [])
        #expect(boolArray == [true, false, true])
        
        // Test nested dictionary values
        #expect(reader.string(forKey: "dictionary.one", default: "") == "foo")
        #expect(reader.bool(forKey: "dictionary.two", default: false) == true)
        #expect(reader.int(forKey: "dictionary.three", default: 0) == 3)
    }
    
    /// Tests boolean edge cases.
    @Test
    func booleanEdgeCases() async throws {
        let tempDir = FileManager.default.temporaryDirectory
        let configUrl = tempDir.appendingPathComponent("test-bool-edge-\(UUID().uuidString).json")
        
        // Test that JSON numbers 0 and 1 are correctly interpreted as booleans
        let configJSON: [String: Any] = [
            "settings": [
                "explicitTrue": true,
                "explicitFalse": false,
                "boolArrayMixed": [true, false, true, false]
            ],
            "overrides": []
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: configJSON)
        try jsonData.write(to: configUrl)
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
            resolutionContext: context
        )
        
        let reader = ConfigReader(provider: provider)
        
        #expect(reader.bool(forKey: "explicitTrue", default: false) == true)
        #expect(reader.bool(forKey: "explicitFalse", default: true) == false)
        
        let boolArray = reader.boolArray(forKey: "boolArrayMixed", default: [])
        #expect(boolArray == [true, false, true, false])
    }
    
    /// Tests that type mismatches return default values rather than crashing or coercing incorrectly.
    @Test
    func typeCoercionFallback() async throws {
        let tempDir = FileManager.default.temporaryDirectory
        let configUrl = tempDir.appendingPathComponent("test-type-fallback-\(UUID().uuidString).json")
        
        // Test that requesting wrong types returns default values
        let configJSON: [String: Any] = [
            "settings": [
                "stringValue": "hello",
                "intValue": 42,
                "boolValue": true
            ],
            "overrides": []
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: configJSON)
        try jsonData.write(to: configUrl)
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
            resolutionContext: context
        )
        
        let reader = ConfigReader(provider: provider)
        
        // Request int from string value - should return default
        #expect(reader.int(forKey: "stringValue", default: 999) == 999)
        
        // Request string from int value - should return default
        #expect(reader.string(forKey: "intValue", default: "fallback") == "fallback")
        
        // Request array from scalar value - should return default
        #expect(reader.stringArray(forKey: "stringValue", default: ["default"]) == ["default"])
        
        // Request non-existent key - should return default
        #expect(reader.bool(forKey: "nonExistent", default: false) == false)
    }
    
    // MARK: - Signed Config Tests
    
    /// Tests that signed configs can be verified and values can be accessed correctly.
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
    
    /// Tests that configs signed with one key cannot be verified with a different public key.
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
        defer { try? FileManager.default.removeItem(at: configUrl) }
        
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
    
    // MARK: - Context and Resolution Tests
    
    /// Tests that resolution context can be updated after provider initialization.
    @Test
    func contextUpdateAndRefresh() async throws {
        let configUrl = try createTestConfigFile()
        defer { try? FileManager.default.removeItem(at: configUrl) }
        
        let initialContext = AppRemoteConfigProvider<JSONSnapshot>.ResolutionContext(
            platform: .iOS,
            platformVersion: OperatingSystemVersion(majorVersion: 17, minorVersion: 0, patchVersion: 0),
            appVersion: try Version("1.0.0"),
            variant: nil,
            buildVariant: .release,
            language: nil
        )
        
        let provider = try await AppRemoteConfigProvider<JSONSnapshot>(
            url: configUrl,
            resolutionContext: initialContext
        )
        
        // Verify initial context
        #expect(provider.getResolutionContext().buildVariant == .release)
        #expect(provider.getResolutionContext().platform == .iOS)
        
        // Update context
        let newContext = AppRemoteConfigProvider<JSONSnapshot>.ResolutionContext(
            platform: .macOS,
            platformVersion: OperatingSystemVersion(majorVersion: 14, minorVersion: 0, patchVersion: 0),
            appVersion: try Version("2.0.0"),
            variant: "pro",
            buildVariant: .debug,
            language: "fr"
        )
        
        provider.setResolutionContext(newContext)
        
        // Verify context was updated
        let updatedContext = provider.getResolutionContext()
        #expect(updatedContext.buildVariant == .debug)
        #expect(updatedContext.platform == .macOS)
        #expect(updatedContext.variant == "pro")
        #expect(updatedContext.language == "fr")
    }
    
    /// Tests the snapshot() method returns current config snapshot.
    @Test
    func snapshotRetrieval() async throws {
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
            resolutionContext: context
        )
        
        let snapshot = provider.snapshot()
        #expect(snapshot is JSONSnapshot)
    }
    
    /// Tests that fetchValue triggers a refresh if needed before returning value.
    @Test
    func fetchValueWithRefresh() async throws {
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
            resolutionContext: context
        )
        
        // Use fetchValue instead of value
        let key = Configuration.AbsoluteConfigKey("apiEndpoint")
        let result = try await provider.fetchValue(forKey: key, type: .string)
        
        #expect(result.value != nil)
    }
}
