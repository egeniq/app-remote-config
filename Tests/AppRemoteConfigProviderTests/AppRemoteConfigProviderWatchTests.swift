import Testing
import Foundation
import Configuration
import Crypto
@testable import AppRemoteConfigProvider
@testable import AppRemoteConfig

/// Tests for AppRemoteConfigProvider's value and snapshot watching functionality.
struct AppRemoteConfigProviderWatchTests {
    
    // MARK: - Helper Methods
    
    /// Creates a JSON config file at a temporary URL.
    func createTestConfigFile(betaMode: Bool = false) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let configUrl = tempDir.appendingPathComponent("test-watch-config-\(UUID().uuidString).json")
        
        let configJSON: [String: Any] = [
            "settings": [
                "betaMode": betaMode,
                "apiEndpoint": "https://api.example.com",
                "counter": 0
            ],
            "overrides": []
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: configJSON)
        try jsonData.write(to: configUrl)
        
        return configUrl
    }
    
    /// Updates an existing config file with new values.
    func updateConfigFile(url: URL, betaMode: Bool, counter: Int) throws {
        let configJSON: [String: Any] = [
            "settings": [
                "betaMode": betaMode,
                "apiEndpoint": "https://api.example.com",
                "counter": counter
            ],
            "overrides": []
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: configJSON)
        try jsonData.write(to: url)
    }
    
    // MARK: - watchValue Tests
    
    /// Tests that watchValue yields initial value immediately.
    @Test
    func watchValueYieldsInitialValue() async throws {
        let configUrl = try createTestConfigFile(betaMode: true)
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
            pollInterval: nil, // Disable polling for this test
            resolutionContext: context
        )
        
        let key = Configuration.AbsoluteConfigKey("betaMode")
        var receivedValues: [Bool] = []
        
        let result = try await provider.watchValue(forKey: key, type: .bool) { updates in
            for try await update in updates {
                if case .success(let lookupResult) = update,
                   case .bool(let value) = lookupResult.value?.value {
                    receivedValues.append(value)
                    // Only collect first value for this test
                    break
                }
            }
        }
        
        // Should have received the initial value
        #expect(receivedValues.count == 1)
        #expect(receivedValues[0] == true)
    }
    
    /// Tests that watchValue receives updates when config file changes.
    @Test
    func watchValueReceivesUpdates() async throws {
        let configUrl = try createTestConfigFile(betaMode: false)
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
            pollInterval: nil, // Disable automatic polling
            resolutionContext: context
        )
        
        let key = Configuration.AbsoluteConfigKey("counter")
        var receivedValues: [Int] = []
        
        // Start watching in a separate task
        let watchTask = Task {
            try await provider.watchValue(forKey: key, type: .int) { updates in
                for try await update in updates {
                    if case .success(let lookupResult) = update,
                       case .int(let value) = lookupResult.value?.value {
                        receivedValues.append(value)
                        if receivedValues.count >= 3 {
                            break
                        }
                    }
                }
            }
        }
        
        // Wait a bit for watcher to be set up
        try await Task.sleep(for: .milliseconds(50))
        
        // Update the config file
        try updateConfigFile(url: configUrl, betaMode: false, counter: 1)
        try await provider.refresh()
        try await Task.sleep(for: .milliseconds(50))
        
        // Update again
        try updateConfigFile(url: configUrl, betaMode: false, counter: 2)
        try await provider.refresh()
        try await Task.sleep(for: .milliseconds(50))
        
        try await watchTask.value
        
        // Should have received initial value + 2 updates
        #expect(receivedValues.count == 3)
        #expect(receivedValues == [0, 1, 2])
    }
    
    /// Tests that multiple watchers can observe the same key simultaneously.
    @Test
    func multipleWatchersOnSameKey() async throws {
        let configUrl = try createTestConfigFile(betaMode: false)
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
        
        let key = Configuration.AbsoluteConfigKey("counter")
        var watcher1Values: [Int] = []
        var watcher2Values: [Int] = []
        
        // Start two watchers
        let task1 = Task {
            try await provider.watchValue(forKey: key, type: .int) { updates in
                for try await update in updates {
                    if case .success(let lookupResult) = update,
                       case .int(let value) = lookupResult.value?.value {
                        watcher1Values.append(value)
                        if watcher1Values.count >= 2 {
                            break
                        }
                    }
                }
            }
        }
        
        let task2 = Task {
            try await provider.watchValue(forKey: key, type: .int) { updates in
                for try await update in updates {
                    if case .success(let lookupResult) = update,
                       case .int(let value) = lookupResult.value?.value {
                        watcher2Values.append(value)
                        if watcher2Values.count >= 2 {
                            break
                        }
                    }
                }
            }
        }
        
        try await Task.sleep(for: .milliseconds(50))
        
        // Update config
        try updateConfigFile(url: configUrl, betaMode: false, counter: 10)
        try await provider.refresh()
        
        try await task1.value
        try await task2.value
        
        // Both watchers should receive both values
        #expect(watcher1Values == [0, 10])
        #expect(watcher2Values == [0, 10])
    }
    
    // MARK: - watchSnapshot Tests
    
    /// Tests that watchSnapshot yields initial snapshot immediately.
    @Test
    func watchSnapshotYieldsInitialSnapshot() async throws {
        let configUrl = try createTestConfigFile(betaMode: true)
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
        
        var snapshotCount = 0
        
        try await provider.watchSnapshot { updates in
            for await snapshot in updates {
                #expect(snapshot is JSONSnapshot)
                snapshotCount += 1
                // Only collect first snapshot
                break
            }
        }
        
        #expect(snapshotCount == 1)
    }
    
    /// Tests that watchSnapshot receives updates when config changes.
    @Test
    func watchSnapshotReceivesUpdates() async throws {
        let configUrl = try createTestConfigFile(betaMode: false)
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
        
        var snapshotCount = 0
        
        let watchTask = Task {
            try await provider.watchSnapshot { updates in
                for await _ in updates {
                    snapshotCount += 1
                    if snapshotCount >= 2 {
                        break
                    }
                }
            }
        }
        
        try await Task.sleep(for: .milliseconds(50))
        
        // Update config
        try updateConfigFile(url: configUrl, betaMode: true, counter: 5)
        try await provider.refresh()
        try await Task.sleep(for: .milliseconds(50))
        
        try await watchTask.value
        
        // Should have received initial + 1 update
        #expect(snapshotCount == 2)
    }
    
    /// Tests that multiple snapshot watchers work simultaneously.
    @Test
    func multipleSnapshotWatchers() async throws {
        let configUrl = try createTestConfigFile(betaMode: false)
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
        
        var watcher1Count = 0
        var watcher2Count = 0
        
        let task1 = Task {
            try await provider.watchSnapshot { updates in
                for await _ in updates {
                    watcher1Count += 1
                    if watcher1Count >= 2 {
                        break
                    }
                }
            }
        }
        
        let task2 = Task {
            try await provider.watchSnapshot { updates in
                for await _ in updates {
                    watcher2Count += 1
                    if watcher2Count >= 2 {
                        break
                    }
                }
            }
        }
        
        try await Task.sleep(for: .milliseconds(50))
        
        // Trigger update
        try updateConfigFile(url: configUrl, betaMode: true, counter: 99)
        try await provider.refresh()
        
        try await task1.value
        try await task2.value
        
        #expect(watcher1Count == 2)
        #expect(watcher2Count == 2)
    }
}
