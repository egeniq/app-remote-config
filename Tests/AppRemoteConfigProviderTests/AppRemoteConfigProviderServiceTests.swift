import Testing
import Foundation
import Configuration
@testable import AppRemoteConfigProvider
@testable import AppRemoteConfig

/// Tests for AppRemoteConfigProvider's Service protocol implementation,
/// including polling behavior, refresh intervals, and lifecycle management.
struct AppRemoteConfigProviderServiceTests {
    
    // MARK: - Helper Methods
    
    /// Creates a JSON config file at a temporary URL.
    func createTestConfigFile(counter: Int = 0) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let configUrl = tempDir.appendingPathComponent("test-service-config-\(UUID().uuidString).json")
        
        let configJSON: [String: Any] = [
            "settings": [
                "counter": counter,
                "feature": true
            ],
            "overrides": []
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: configJSON)
        try jsonData.write(to: configUrl)
        
        return configUrl
    }
    
    /// Updates an existing config file with new counter value.
    func updateConfigFile(url: URL, counter: Int) throws {
        let configJSON: [String: Any] = [
            "settings": [
                "counter": counter,
                "feature": true
            ],
            "overrides": []
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: configJSON)
        try jsonData.write(to: url)
    }
    
    // MARK: - Polling Behavior Tests
    
    /// Tests that run() method polls at the specified interval.
    @Test
    func servicePollsAtSpecifiedInterval() async throws {
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
        
        // Create provider with 100ms poll interval
        let provider = try await AppRemoteConfigProvider<JSONSnapshot>(
            url: configUrl,
            pollInterval: .milliseconds(100),
            resolutionContext: context
        )
        
        let key = Configuration.AbsoluteConfigKey("counter")
        var receivedValues: [Int] = []
        
        // Start watching to capture updates
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
        
        // Start the service in background
        let serviceTask = Task {
            try await provider.run()
        }
        
        // Wait for initial value
        try await Task.sleep(for: .milliseconds(50))
        
        // Update file multiple times
        try updateConfigFile(url: configUrl, counter: 1)
        try await Task.sleep(for: .milliseconds(150)) // Wait for poll
        
        try updateConfigFile(url: configUrl, counter: 2)
        try await Task.sleep(for: .milliseconds(150)) // Wait for poll
        
        // Stop the service
        serviceTask.cancel()
        
        try await watchTask.value
        
        // Should have received values from polling
        #expect(receivedValues.count >= 2)
        #expect(receivedValues.contains(0))
        #expect(receivedValues.contains(1) || receivedValues.contains(2))
    }
    
    /// Tests that service can be gracefully stopped.
    @Test
    func serviceGracefulShutdown() async throws {
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
            pollInterval: .milliseconds(50),
            resolutionContext: context
        )
        
        // Start the service
        let serviceTask = Task {
            try await provider.run()
        }
        
        // Let it run for a bit
        try await Task.sleep(for: .milliseconds(100))
        
        // Cancel the service
        serviceTask.cancel()
        
        // Wait for cancellation to complete
        do {
            try await serviceTask.value
            Issue.record("Expected CancellationError to be thrown")
        } catch is CancellationError {
            // Expected - service was cancelled
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
    
    /// Tests that service doesn't poll when pollInterval is nil.
    @Test
    func serviceWithNoPollInterval() async throws {
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
            pollInterval: nil, // No polling
            resolutionContext: context
        )
        
        let key = Configuration.AbsoluteConfigKey("counter")
        var receivedValues: [Int] = []
        
        // Start watching
        let watchTask = Task {
            try await provider.watchValue(forKey: key, type: .int) { updates in
                for try await update in updates {
                    if case .success(let lookupResult) = update,
                       case .int(let value) = lookupResult.value?.value {
                        receivedValues.append(value)
                    }
                }
            }
        }
        
        // Start service (should complete immediately since no poll interval)
        let serviceTask = Task {
            try await provider.run()
        }
        
        // Update file
        try updateConfigFile(url: configUrl, counter: 5)
        try await Task.sleep(for: .milliseconds(200))
        
        // Should only have initial value, no automatic updates
        #expect(receivedValues == [0])
        
        serviceTask.cancel()
        watchTask.cancel()
    }
    
    // MARK: - Minimum Refresh Interval Tests
    
    /// Tests that minimum refresh interval prevents excessive refreshes.
    @Test
    func minimumRefreshIntervalEnforced() async throws {
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
            resolutionContext: context,
            minimumRefreshInterval: .seconds(1) // 1 second minimum
        )
        
        let key = Configuration.AbsoluteConfigKey("counter")
        
        // Get initial value
        let reader = await provider.snapshot().reader
        let initial = reader.int(forKey: "counter")
        #expect(initial == 0)
        
        // Update file and refresh immediately
        try updateConfigFile(url: configUrl, counter: 1)
        try await provider.refresh()
        
        let afterFirst = await provider.snapshot().reader.int(forKey: "counter")
        #expect(afterFirst == 1)
        
        // Update file again and try to refresh immediately (should be ignored)
        try updateConfigFile(url: configUrl, counter: 2)
        try await provider.refresh() // Should be rate-limited
        
        let afterSecond = await provider.snapshot().reader.int(forKey: "counter")
        #expect(afterSecond == 1) // Should still be 1, not 2
        
        // Wait for minimum interval to pass
        try await Task.sleep(for: .seconds(1.1))
        
        // Now refresh should work
        try await provider.refresh()
        let afterWait = await provider.snapshot().reader.int(forKey: "counter")
        #expect(afterWait == 2)
    }
    
    /// Tests that force refresh bypasses minimum interval.
    @Test
    func forceRefreshBypassesMinimumInterval() async throws {
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
            resolutionContext: context,
            minimumRefreshInterval: .seconds(10) // Long interval
        )
        
        // Update and force refresh
        try updateConfigFile(url: configUrl, counter: 1)
        try await provider.refresh(force: true)
        
        let value1 = await provider.snapshot().reader.int(forKey: "counter")
        #expect(value1 == 1)
        
        // Update and force refresh again immediately
        try updateConfigFile(url: configUrl, counter: 2)
        try await provider.refresh(force: true)
        
        let value2 = await provider.snapshot().reader.int(forKey: "counter")
        #expect(value2 == 2) // Should have updated despite minimum interval
    }
    
    // MARK: - File Change Detection Tests
    
    /// Tests that provider detects when file content changes.
    @Test
    func fileChangeDetection() async throws {
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
        
        let key = Configuration.AbsoluteConfigKey("counter")
        let initial = await provider.snapshot().reader.int(forKey: "counter")
        #expect(initial == 0)
        
        // Modify file
        try updateConfigFile(url: configUrl, counter: 42)
        
        // Refresh should detect the change
        try await provider.refresh()
        
        let updated = await provider.snapshot().reader.int(forKey: "counter")
        #expect(updated == 42)
    }
    
    /// Tests that provider handles file with same content (no unnecessary updates).
    @Test
    func noUpdateWhenFileUnchanged() async throws {
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
        
        var snapshotCount = 0
        
        // Watch for snapshot changes
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
        
        // Refresh without changing file (write same content)
        try updateConfigFile(url: configUrl, counter: 0)
        try await provider.refresh()
        
        try await Task.sleep(for: .milliseconds(100))
        
        watchTask.cancel()
        
        // Should only have initial snapshot, no update since content didn't change
        #expect(snapshotCount == 1)
    }
}
