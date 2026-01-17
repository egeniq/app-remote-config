import SwiftUI
import Foundation
import AppRemoteConfigProvider
import AppRemoteConfig
import Configuration
import ConfigurationSharing
import Dependencies
import Logging
import ServiceLifecycle

@main
struct SwiftUISharingExampleApp: App {
    @Environment(\.scenePhase) private var scenePhase
    
    init() {
        // Prepare dependencies early in the app lifecycle with async initialization factory
        prepareDependencies {
            $0.defaultConfigurationReader = DefaultConfigurationReader(initialize: {
                try await Self.createMyConfigReader()
            })
        }
    }
    
    /// Factory method to create the configuration reader with services for lifecycle management
    private static func createMyConfigReader() async throws -> (ConfigReader, [any Service]?, Logger?) {
        // Step 1: Create an example configuration file
        let configFileURL = try createExampleConfigFile()
        
        // Step 2: Automatically detect platform
        let platform: Platform
        #if os(iOS)
        platform = .iOS
        #elseif os(macOS)
        platform = .macOS
        #elseif os(tvOS)
        platform = .tvOS
        #elseif os(watchOS)
        platform = .watchOS
        #else
        platform = .iOS
        #endif
        
        // Step 3: Gather system information
        let osVersion = ProcessInfo.processInfo.operatingSystemVersion
        let appVersionString = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let appVersion = try Version(appVersionString)
        
        #if DEBUG
        let buildVariant: BuildVariant = .debug
        #else
        let buildVariant: BuildVariant = .release
        #endif
        
        // Step 4: Create resolution context
        let resolutionContext = AppRemoteConfigProvider<JSONSnapshot>.ResolutionContext(
            platform: platform,
            platformVersion: osVersion,
            appVersion: appVersion,
            variant: nil,
            buildVariant: buildVariant,
            language: Locale.current.language.languageCode?.identifier
        )
        
        // Step 5: Create logger
        var logger = Logger(label: "com.example.remoteconfigsharing")
        logger.logLevel = .debug
        
        // Step 6: Create provider
        let provider = try await AppRemoteConfigProvider<JSONSnapshot>(
            url: configFileURL,
            pollInterval: .seconds(30),
            minimumRefreshInterval: .seconds(5),
            resolutionContext: resolutionContext,
            logger: logger
        )
        
        logger.info("AppRemoteConfigProvider initialized successfully")
        logger.info("Platform: \(platform), OS: \(osVersion.majorVersion).\(osVersion.minorVersion).\(osVersion.patchVersion)")
        logger.info("App version: \(appVersion), Build variant: \(buildVariant)")
        
        // Return the reader, services that need lifecycle management, and logger
        // AppRemoteConfigProvider conforms to Service, so it will be managed automatically
        return (ConfigReader(providers: [provider]), [provider], logger)
    }
    
    /// Create an example configuration JSON file
    private static func createExampleConfigFile() throws -> URL {
        let scheduledStart = ISO8601DateFormatter().string(from: Date().addingTimeInterval(3))
        let scheduledEnd = ISO8601DateFormatter().string(from: Date().addingTimeInterval(13))
        let exampleConfig: [String: Any] = [
            "settings": [
                "appName": "Swift Sharing Configuration Example",
                "features": [
                    "betaMode": false,
                    "newUI": false,
                    "darkMode": true
                ],
                "apiEndpoint": "https://api.example.com/v1",
                "timeout": 30,
                "maxRetries": 3
            ],
            "overrides": [
                [
                    "schedule": [
                        "from": scheduledStart,
                        "until": scheduledEnd
                    ],
                    "settings": [
                        "features": [
                            "betaMode": true,
                            "newUI": true,
                            "darkMode": true
                        ]
                    ]
                ]
            ]
        ]
        
        let jsonData = try JSONSerialization.data(
            withJSONObject: exampleConfig,
            options: [.prettyPrinted, .sortedKeys]
        )
        
        let tempDirectory = FileManager.default.temporaryDirectory
        let configURL = tempDirectory.appendingPathComponent("remote-config-sharing.json")
        
        try jsonData.write(to: configURL, options: .atomic)
        return configURL
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active {
                Task {
                    // Refresh the configuration when app comes to foreground
                    @Dependency(\.defaultConfigurationReader) var reader
                    await reader.refresh()
                }
            }
        }
    }
}
