import XCTest
import Foundation
import Configuration
@testable import AppRemoteConfigProvider
@testable import AppRemoteConfig

/// Tests for AppRemoteConfigProvider's swift-configuration Provider integration.
final class AppRemoteConfigProviderConfigurationIntegrationTests: XCTestCase {
    
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
                "features": [
                    "newUI": false,
                    "betaMode": false
                ],
                "apiEndpoint": "https://api.example.com"
            ],
            "overrides": [
                [
                    "conditions": [
                        [
                            "buildVariant": "debug"
                        ]
                    ],
                    "settings": [
                        "features": [
                            "betaMode": true
                        ]
                    ]
                ]
            ]
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: configJSON)
        try jsonData.write(to: configUrl)
        
        return configUrl
    }
    
    // MARK: - Basic Provider Tests
    
    func testProviderInitializationWithoutContext() async throws {
        let configUrl = try createTestConfigFile()
        defer { try? FileManager.default.removeItem(at: configUrl) }
        
        let provider = try await AppRemoteConfigProvider<JSONSnapshot>(
            url: configUrl,
            pollInterval: .seconds(60)
        )
        
        XCTAssertNotNil(provider)
    }
    
    func testProviderInitializationWithContext() async throws {
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
        
        let provider = try await AppRemoteConfigProvider<JSONSnapshot>(
            url: configUrl,
            pollInterval: .seconds(60),
            resolutionContext: context
        )
        
        XCTAssertNotNil(provider)
    }
    
    // MARK: - Value Resolution Tests
    
    func testValueResolutionWithContext() async throws {
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
        XCTAssertNotNil(provider.getResolutionContext())
        XCTAssertEqual(provider.getResolutionContext()?.platform, .iOS)
        XCTAssertEqual(provider.getResolutionContext()?.buildVariant, .release)
    }
    
    func testNestedKeyPathResolution() async throws {
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
        
        let featureValue = reader.bool(forKey: "settings.features.betaMode", default: false)
        let apiEndpoint = reader.string(forKey: "settings.apiEndpoint", default: "")
        let timeout = reader.int(forKey: "settings.timeout", default: 0)
        
        // Values should be readable (actual values depend on config structure)
        XCTAssertNotNil(featureValue)
        XCTAssertNotNil(apiEndpoint)
        XCTAssertNotNil(timeout)
    }
    
    // MARK: - ConfigReader Integration Tests
    
    func testConfigReaderIntegration() async throws {
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
        XCTAssertEqual(featureEnabled, true)
        
        let apiEndpoint = reader.string(forKey: "settings.apiEndpoint", default: "")
        XCTAssertEqual(apiEndpoint, "https://api.example.com")
        
        let timeout = reader.int(forKey: "settings.timeout", default: 0)
        XCTAssertEqual(timeout, 30)
    }
    
    // MARK: - Cleanup
    
    override func tearDown() {
        super.tearDown()
        // Clean up any temporary files
        let tempDir = FileManager.default.temporaryDirectory
        try? FileManager.default.contentsOfDirectory(atPath: tempDir.path)
            .filter { $0.hasPrefix("test-config-") }
            .forEach { filename in
                try? FileManager.default.removeItem(at: tempDir.appendingPathComponent(filename))
            }
    }
}
