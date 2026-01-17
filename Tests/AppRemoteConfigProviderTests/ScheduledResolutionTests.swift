import Testing
import Foundation
import Configuration
@testable import AppRemoteConfigProvider
@testable import AppRemoteConfig

/// Tests for scheduled resolution timer functionality.
struct ScheduledResolutionTests {
    
    // MARK: - Helper Methods
    
    /// Creates a JSON config file with scheduled overrides.
    func createConfigWithScheduledOverrides(scheduledInSeconds: Int) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let configUrl = tempDir.appendingPathComponent("test-scheduled-\(UUID().uuidString).json")
        
        let scheduledStart = ISO8601DateFormatter().string(from: Date().addingTimeInterval(Double(scheduledInSeconds)))
        let scheduledEnd = ISO8601DateFormatter().string(from: Date().addingTimeInterval(Double(scheduledInSeconds + 10)))
        
        let configJSON: [String: Any] = [
            "settings": [
                "featureEnabled": false,
                "counter": 0
            ],
            "overrides": [
                [
                    "schedule": [
                        "from": scheduledStart,
                        "until": scheduledEnd
                    ],
                    "settings": [
                        "featureEnabled": true,
                        "counter": 42
                    ]
                ]
            ]
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: configJSON)
        try jsonData.write(to: configUrl)
        
        return configUrl
    }
    
    // MARK: - Tests
    
    /// Tests that AppRemoteConfigProvider initializes successfully with scheduled overrides.
    @Test("Provider initializes with scheduled overrides")
    func initializesWithScheduledOverrides() async throws {
        let configUrl = try createConfigWithScheduledOverrides(scheduledInSeconds: 10)
        defer { try? FileManager.default.removeItem(at: configUrl) }
        
        let context = AppRemoteConfigProvider<JSONSnapshot>.ResolutionContext(
            platform: .iOS,
            platformVersion: OperatingSystemVersion(majorVersion: 17, minorVersion: 0, patchVersion: 0),
            appVersion: try Version("1.0.0"),
            variant: nil,
            buildVariant: .release,
            language: nil
        )
        
        // Should not throw
        let provider = try await AppRemoteConfigProvider<JSONSnapshot>(
            url: configUrl,
            pollInterval: nil,
            resolutionContext: context
        )
        
        // The initial snapshot should have featureEnabled = false (before schedule)
        let reader1 = ConfigReader(provider: provider)
        let featureBefore = reader1.bool(forKey: "featureEnabled", default: false)
        #expect(featureBefore == false, "Feature should be disabled initially")
    }
    
    /// Tests that the provider correctly resolves configuration after scheduled time.
    @Test("Provider resolves scheduled overrides when time passes")
    func resolvesScheduledOverridesWhenTimePasses() async throws {
        let configUrl = try createConfigWithScheduledOverrides(scheduledInSeconds: 1)
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
        
        // The initial snapshot should have featureEnabled = false
        let reader1 = ConfigReader(provider: provider)
        let featureBefore = reader1.bool(forKey: "featureEnabled", default: false)
        #expect(featureBefore == false)
        
        // Manually trigger refresh which should re-resolve with current time
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        try await provider.refresh()
        
        // Now the feature should be enabled (we've passed the 1-second mark)
        let reader2 = ConfigReader(provider: provider)
        let featureAfter = reader2.bool(forKey: "featureEnabled", default: false)
        #expect(featureAfter == true, "Feature should be enabled after scheduled time has passed")
    }
}
