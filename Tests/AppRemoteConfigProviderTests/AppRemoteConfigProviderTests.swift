import Testing
import Foundation
import Configuration
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
    func providerInitializationWithoutContext() async throws {
        let configUrl = try createTestConfigFile()
        defer { try? FileManager.default.removeItem(at: configUrl) }
        
        let _ = try await AppRemoteConfigProvider<JSONSnapshot>(
            url: configUrl,
            pollInterval: .seconds(60)
        )
    }
    
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
    
    // MARK: - Value Resolution Tests
    
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
        #expect(provider.getResolutionContext() != nil)
        #expect(provider.getResolutionContext()?.platform == .iOS)
        #expect(provider.getResolutionContext()?.buildVariant == .release)
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
        let betaMode = reader.bool(forKey: "settings.features.betaMode", default: true)
        let newUI = reader.bool(forKey: "settings.features.newUI", default: false)
        let apiEndpoint = reader.string(forKey: "settings.apiEndpoint", default: "")
        let timeout = reader.int(forKey: "settings.timeout", default: 0)
        
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
        
        try await Task.sleep(for: .milliseconds(200))
        
        let featureEnabled = reader.bool(forKey: "settings.features.newUI", default: false)
        #expect(featureEnabled == true)
        
        let apiEndpoint = reader.string(forKey: "settings.apiEndpoint", default: "")
        #expect(apiEndpoint == "https://api.example.com")
        
        let timeout = reader.int(forKey: "settings.timeout", default: 0)
        #expect(timeout == 30)
    }
}
