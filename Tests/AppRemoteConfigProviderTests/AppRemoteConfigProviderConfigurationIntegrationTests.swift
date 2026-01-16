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
        
        let contextProvider = InMemoryProvider(values: [
            "platform.name": "iOS",
            "platform.version": "17.0.0",
            "app.version": "1.2.0",
            "app.buildVariant": "debug"
        ])
        
        let provider = try await AppRemoteConfigProvider<JSONSnapshot>(
            url: configUrl,
            pollInterval: .seconds(60),
            contextProvider: contextProvider
        )
        
        XCTAssertNotNil(provider)
    }
    
    // MARK: - Value Resolution Tests
    
    func testValueResolutionWithContext() async throws {
        let configUrl = try createTestConfigFile()
        defer { try? FileManager.default.removeItem(at: configUrl) }
        
        let contextProvider = InMemoryProvider(values: [
            "platform.name": "iOS",
            "platform.version": "17.0.0",
            "app.version": "1.2.0",
            "app.buildVariant": "release",
            "app.language": "en"
        ])
        
        let provider = try await AppRemoteConfigProvider<JSONSnapshot>(
            url: configUrl,
            pollInterval: .seconds(60),
            contextProvider: contextProvider
        )
        
        // Allow time for initial resolution
        try await Task.sleep(for: .milliseconds(200))
        
        let value = provider.value(forKey: "settings.features.newUI")
        XCTAssertEqual(value as? Bool, true)
    }
    
    func testNestedKeyPathResolution() async throws {
        let configUrl = try createTestConfigFile()
        defer { try? FileManager.default.removeItem(at: configUrl) }
        
        let contextProvider = InMemoryProvider(values: [
            "platform.name": "iOS",
            "platform.version": "17.0.0",
            "app.version": "1.2.0",
            "app.buildVariant": "release",
            "app.language": "en"
        ])
        
        let provider = try await AppRemoteConfigProvider<JSONSnapshot>(
            url: configUrl,
            pollInterval: .seconds(60),
            contextProvider: contextProvider
        )
        
        try await Task.sleep(for: .milliseconds(200))
        
        // Test nested paths
        let featureValue = provider.value(forKey: "settings.features.betaMode")
        XCTAssertEqual(featureValue as? Bool, false)
        
        let apiEndpoint = provider.value(forKey: "settings.apiEndpoint")
        XCTAssertEqual(apiEndpoint as? String, "https://api.example.com")
        
        let timeout = provider.value(forKey: "settings.timeout")
        XCTAssertEqual(timeout as? Int, 30)
    }
    
    // MARK: - ConfigReader Integration Tests
    
    func testConfigReaderIntegration() async throws {
        let configUrl = try createTestConfigFile()
        defer { try? FileManager.default.removeItem(at: configUrl) }
        
        let contextProvider = InMemoryProvider(values: [
            "platform.name": "iOS",
            "platform.version": "17.0.0",
            "app.version": "1.2.0",
            "app.buildVariant": "release",
            "app.language": "en"
        ])
        
        let provider = try await AppRemoteConfigProvider<JSONSnapshot>(
            url: configUrl,
            pollInterval: .seconds(60),
            contextProvider: contextProvider
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
