import SwiftUI
import Foundation
import AppRemoteConfigProvider
import AppRemoteConfig
import Configuration
import Logging
import ServiceLifecycle

@main
struct SwiftUIExampleApp: App {
    @State private var viewModel: ContentViewViewModel?
    @State private var error: String?
    @State private var serviceGroup: ServiceGroup?
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                if let error = error {
                    ErrorView(message: error)
                } else if let viewModel = viewModel {
                    ContentView(viewModel: viewModel)
                } else {
                    ProgressView("Initializing Configuration...")
                        .task {
                            await initializeProvider()
                        }
                }
            }
            .onChange(of: scenePhase) { oldPhase, newPhase in
                if newPhase == .active {
                    // Refresh configuration when app comes to foreground
                    Task {
                        await viewModel?.refresh()
                    }
                }
            }
        }
    }
    
    /// Initialize the AppRemoteConfigProvider with proper ResolutionContext
    private func initializeProvider() async {
        do {
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
            platform = .iOS  // Default fallback
            #endif
            
            // Step 3: Fetch OS version once
            let osVersion = ProcessInfo.processInfo.operatingSystemVersion
            
            // Step 4: Read app version from Info.plist
            let appVersionString = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
            let appVersion = try Version(appVersionString)
            
            // Step 5: Determine build variant from DEBUG flag
            let buildVariant: BuildVariant
            #if DEBUG
            buildVariant = .debug
            #else
            buildVariant = .release
            #endif
            
            // Step 6: Create the ResolutionContext with detected values
            let resolutionContext = AppRemoteConfigProvider<JSONSnapshot>.ResolutionContext(
                platform: platform,
                platformVersion: osVersion,
                appVersion: appVersion,
                variant: nil,                             // Optional variant name for A/B testing
                buildVariant: buildVariant,
                language: Locale.current.language.languageCode?.identifier
            )
            
            // Step 7: Create a logger to see provider activity
            var logger = Logger(label: "com.example.remoteconfig")
            logger.logLevel = .debug  // Set to .debug to see detailed activity
            
            // Step 8: Instantiate AppRemoteConfigProvider with logger
            let provider = try await AppRemoteConfigProvider<JSONSnapshot>(
                url: configFileURL,
                pollInterval: .seconds(30),              // Poll every 30 seconds (nil to disable)
                minimumRefreshInterval: .seconds(5),     // Minimum wait between refreshes
                resolutionContext: resolutionContext,
                logger: logger
            )
            
            logger.info("AppRemoteConfigProvider initialized successfully")
            logger.info("Platform: \(platform), OS: \(osVersion.majorVersion).\(osVersion.minorVersion).\(osVersion.patchVersion)")
            logger.info("App version: \(appVersion), Build variant: \(buildVariant)")
            
            // Step 9: Create ServiceGroup to run the provider (enables polling)
            let serviceGroup = ServiceGroup(
                services: [provider],
                logger: logger
            )
            
            // Step 10: Start the service group in a background task
            Task {
                do {
                    try await serviceGroup.run()
                } catch {
                    logger.error("ServiceGroup error: \(error)")
                }
            }
            
            // Step 11: Create the view model with the initialized provider
            await MainActor.run {
                self.serviceGroup = serviceGroup
                self.viewModel = ContentViewViewModel(provider: provider)
            }
        } catch {
            await MainActor.run {
                self.error = "Failed to initialize configuration: \(error.localizedDescription)"
            }
        }
    }
    
    /// Create an example configuration JSON file
    private func createExampleConfigFile() throws -> URL {
        let scheduledStart = ISO8601DateFormatter().string(from: Date().addingTimeInterval(3))
        let exampleConfig: [String: Any] = [
            "settings": [
                "appName": "Remote Config Example App",
                "features": [
                    "betaMode": true,
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
                        "from": scheduledStart
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
        let configURL = tempDirectory.appendingPathComponent("remote-config.json")
        
        try jsonData.write(to: configURL, options: .atomic)
        return configURL
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
