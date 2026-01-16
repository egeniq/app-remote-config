import SwiftUI
import Foundation
import AppRemoteConfigProvider
import AppRemoteConfig
import Configuration

// Note: We use @testable to access internal initializers for this example
// In production, you would use the public convenience initializer with ConfigReader
@testable import AppRemoteConfigProvider

@main
struct SwiftUIExampleApp: App {
    @State private var viewModel: ContentViewViewModel?
    @State private var error: String?
    
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
        }
    }
    
    /// Initialize the AppRemoteConfigProvider with proper ResolutionContext
    private func initializeProvider() async {
        do {
            // Step 1: Create an example configuration file
            let configFileURL = try createExampleConfigFile()
            
            // Step 2: Create the ResolutionContext with platform and app information
            let resolutionContext = AppRemoteConfigProvider<JSONSnapshot>.ResolutionContext(
                platform: .iOS,                           // Device platform (iOS, macOS, tvOS, watchOS)
                platformVersion: OperatingSystemVersion(  // OS version
                    majorVersion: ProcessInfo.processInfo.operatingSystemVersion.majorVersion,
                    minorVersion: ProcessInfo.processInfo.operatingSystemVersion.minorVersion,
                    patchVersion: ProcessInfo.processInfo.operatingSystemVersion.patchVersion
                ),
                appVersion: try Version("1.0.0"),        // App version for variant selection
                variant: nil,                             // Optional variant name for A/B testing
                buildVariant: .debug,                     // Debug or Release build
                language: Locale.current.language.languageCode?.identifier  // User's preferred language
            )
            
            // Step 3: Instantiate AppRemoteConfigProvider
            // This initializer is marked internal but accessible via @testable in this example
            // For production use, you would typically use the convenience init with ConfigReader
            let provider = try await AppRemoteConfigProvider<JSONSnapshot>(
                url: configFileURL,
                pollInterval: .seconds(30),              // Poll every 30 seconds (nil to disable)
                minimumRefreshInterval: .seconds(5),     // Minimum wait between refreshes
                resolutionContext: resolutionContext
            )
            
            // Step 4: Create the view model with the initialized provider
            await MainActor.run {
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
        let exampleConfig: [String: Any] = [
            "appName": "Remote Config Example App",
            "features": [
                "betaMode": true,
                "newUI": true,
                "darkMode": true
            ],
            "apiEndpoint": "https://api.example.com/v1",
            "timeout": 30,
            "maxRetries": 3
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
