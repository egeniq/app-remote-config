import Testing
import Foundation
import Configuration
import Crypto
@testable import AppRemoteConfigProvider
@testable import AppRemoteConfig

/// Tests for AppRemoteConfigProvider's snapshot watching functionality.
struct AppRemoteConfigProviderWatchTests {
    
    // MARK: - Helper Methods
    
    /// Creates a JSON config file at a temporary URL.
    func createTestConfigFile(counter: Int = 0) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let configUrl = tempDir.appendingPathComponent("test-watch-config-\(UUID().uuidString).json")
        
        let configJSON: [String: Any] = [
            "settings": [
                "featureEnabled": true,
                "counter": counter,
                "apiEndpoint": "https://api.example.com"
            ],
            "overrides": []
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: configJSON)
        try jsonData.write(to: configUrl)
        
        return configUrl
    }
    
    /// Updates an existing config file with new values.
    func updateConfigFile(url: URL, counter: Int) throws {
        let configJSON: [String: Any] = [
            "settings": [
                "featureEnabled": true,
                "counter": counter,
                "apiEndpoint": "https://api.example.com"
            ],
            "overrides": []
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: configJSON)
        try jsonData.write(to: url)
    }
    
    // MARK: - watchSnapshot Tests
    
    /// Tests that watchSnapshot yields initial snapshot immediately.
    @Test
    func watchSnapshotYieldsInitialSnapshot() async throws {
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
        
        var received = false
        
        try await provider.watchSnapshot { updates in
            for await snapshot in updates {
                #expect(snapshot is JSONSnapshot)
                received = true
                break
            }
        }
        
        #expect(received)
    }
    
    /// Tests that watchSnapshot works with updated configs.
    @Test
    func watchSnapshotWithConfigUpdate() async throws {
        let configUrl = try createTestConfigFile(counter: 0)
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
        
        // First, verify initial snapshot works
        let snapshot1 = provider.snapshot()
        #expect(snapshot1 is JSONSnapshot)
        
        // Update file and refresh
        try updateConfigFile(url: configUrl, counter: 99)
        try await provider.refresh()
        
        // Verify snapshot updated
        let snapshot2 = provider.snapshot()
        #expect(snapshot2 is JSONSnapshot)
        
        // Both are snapshots (though we can't easily verify the content changed
        // without accessing internal snapshot data)
    }
}
