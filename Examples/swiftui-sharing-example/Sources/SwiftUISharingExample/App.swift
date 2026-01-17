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
    @State private var error: String?
    @State private var isInitializing: Bool = true
    @State private var serviceGroup: ServiceGroup?
    @Environment(\.scenePhase) private var scenePhase
    
    init() {
        // Prepare dependencies early in the app lifecycle with async initialization factory
        prepareDependencies {
            $0.defaultConfigurationReader.initialize = {
                let provider = try await Self.createProvider()
                return ConfigReader(providers: [provider])
            }
        }
    }
    
    /// Factory method to create the configured AppRemoteConfigProvider
    private static func createProvider() async throws -> any ConfigProvider {
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
        
        // Step 6: Create and return provider
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
        
        return provider
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
            ZStack {
                if let error = error {
                    ErrorView(message: error)
                } else if isInitializing {
                    ProgressView("Initializing Configuration...")
                        .task {
                            await initializeProvider()
                        }
                } else {
                    ContentView()
                }
            }
            .onChange(of: scenePhase) { oldPhase, newPhase in
                if newPhase == .active {
                    // Refresh configuration when app comes to foreground
                    Task {
                        // Configuration will update automatically via @Shared
                        // Just trigger a manual refresh if needed
                        if serviceGroup != nil {
                            // Could add a refresh method here if needed
                        }
                    }
                }
            }
        }
    }
    
    /// Initialize the AppRemoteConfigProvider using the async-aware dependency
    private func initializeProvider() async {
        do {
            // Step 1: Initialize provider using the dependency factory
            @Dependency(\.defaultConfigurationReader) var readerFactory
            let configReader = try await readerFactory.initialize()
            
            // Step 2: Get logger for status messages
            var logger = Logger(label: "com.example.remoteconfigsharing")
            logger.logLevel = .debug
            logger.info("Configuration reader ready")
            
            // Step 5: Mark initialization complete
            await MainActor.run {
                self.isInitializing = false
            }
        } catch {
            await MainActor.run {
                self.error = "Failed to initialize configuration: \(error.localizedDescription)"
            }
        }
    }
}


/// View shown when initialization fails
struct ErrorView: View {
    let message: String
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundColor(.red)
            
            Text("Configuration Error")
                .font(.headline)
            
            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(4)
            
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.gray).opacity(0.05))
    }
}
