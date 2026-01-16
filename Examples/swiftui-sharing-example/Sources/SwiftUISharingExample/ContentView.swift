import SwiftUI
import ConfigurationSharing
import Sharing
import AppRemoteConfigProvider
import Configuration
import Dependencies

/// Main content view displaying remote configuration values using ConfigurationSharing
/// This demonstrates simplified reactive configuration reading with @SharedReader
struct ContentView: View {
    @Environment(\.colorScheme) var colorScheme
    
    // Use @SharedReader with ConfigurationKey for reactive configuration values
    // These automatically update whenever the configuration changes
    @SharedReader(.configuration("appName"))
    var appName = "Loading..."
    
    @SharedReader(.configuration("features.betaMode"))
    var betaMode = false
    
    @SharedReader(.configuration("features.newUI"))
    var newUIEnabled = false
    
    @SharedReader(.configuration("features.darkMode"))
    var darkModeEnabled = false
    
    @SharedReader(.configuration("apiEndpoint"))
    var apiEndpoint = "https://default.example.com"
    
    @SharedReader(.configuration("timeout"))
    var timeout = 30
    
    @SharedReader(.configuration("maxRetries"))
    var maxRetries = 3
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // App Header Section
                    VStack(spacing: 8) {
                        Text(appName)
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("Configuration Sharing Example")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(Color(.gray).opacity(0.1))
                    .cornerRadius(12)
                    
                    // Features Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Features")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        FeatureToggleRow(
                            title: "Beta Mode",
                            isEnabled: betaMode,
                            description: "Experimental features enabled"
                        )
                        
                        FeatureToggleRow(
                            title: "New UI",
                            isEnabled: newUIEnabled,
                            description: "Modern user interface"
                        )
                        
                        FeatureToggleRow(
                            title: "Dark Mode",
                            isEnabled: darkModeEnabled,
                            description: "System dark appearance support"
                        )
                    }
                    .padding()
                    .background(Color(.gray).opacity(0.1))
                    .cornerRadius(12)
                    
                    // API Configuration Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("API Configuration")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        ConfigurationItemRow(
                            label: "Endpoint",
                            value: apiEndpoint
                        )
                        
                        Divider()
                        
                        ConfigurationItemRow(
                            label: "Timeout",
                            value: "\(timeout) seconds"
                        )
                        
                        Divider()
                        
                        ConfigurationItemRow(
                            label: "Max Retries",
                            value: "\(maxRetries)"
                        )
                    }
                    .padding()
                    .background(Color(.gray).opacity(0.1))
                    .cornerRadius(12)
                    
                    // Info Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("How It Works")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: "1.circle.fill")
                                    .foregroundColor(.blue)
                                    .font(.title3)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("AppRemoteConfigProvider")
                                        .font(.headline)
                                    Text("Loads and polls configuration from a JSON file")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: "2.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.title3)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("ConfigurationSharing")
                                        .font(.headline)
                                    Text("Bridges Configuration to Swift Sharing with ConfigurationKey")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: "3.circle.fill")
                                    .foregroundColor(.purple)
                                    .font(.title3)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("@SharedReader")
                                        .font(.headline)
                                    Text("Views automatically update when config changes")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding()
                        .background(Color(.gray).opacity(0.05))
                        .cornerRadius(8)
                    }
                    .padding()
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Configuration Sharing")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
    }
}
/// Reusable component for displaying feature toggles
struct FeatureToggleRow: View {
    let title: String
    let isEnabled: Bool
    let description: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .fontWeight(.medium)
                Spacer()
                Badge(
                    text: isEnabled ? "ON" : "OFF",
                    isEnabled: isEnabled
                )
            }
            Text(description)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.gray).opacity(0.05))
        .cornerRadius(8)
    }
}

/// Reusable component for displaying configuration items
struct ConfigurationItemRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
                .lineLimit(1)
        }
        .padding()
        .background(Color(.gray).opacity(0.05))
        .cornerRadius(8)
    }
}

/// Badge component for displaying status
struct Badge: View {
    let text: String
    let isEnabled: Bool
    
    var body: some View {
        Text(text)
            .font(.caption2)
            .fontWeight(.bold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(isEnabled ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
            .foregroundColor(isEnabled ? Color.green : Color.red)
            .cornerRadius(4)
    }
}

#Preview {
    ContentView()
        .preferredColorScheme(.light)
}
