import SwiftUI

/// Main content view displaying remote configuration values
struct ContentView: View {
    @ObservedObject var viewModel: ContentViewViewModel
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // App Header Section
                    VStack(spacing: 8) {
                        Text(viewModel.appName)
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("Remote Configuration Example")
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
                            isEnabled: viewModel.betaMode,
                            description: "Experimental features enabled"
                        )
                        
                        FeatureToggleRow(
                            title: "New UI",
                            isEnabled: viewModel.newUIEnabled,
                            description: "Modern user interface"
                        )
                        
                        FeatureToggleRow(
                            title: "Dark Mode",
                            isEnabled: viewModel.darkModeEnabled,
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
                            value: viewModel.apiEndpoint
                        )
                        
                        Divider()
                        
                        ConfigurationItemRow(
                            label: "Timeout",
                            value: "\(viewModel.timeout) seconds"
                        )
                        
                        Divider()
                        
                        ConfigurationItemRow(
                            label: "Max Retries",
                            value: "\(viewModel.maxRetries)"
                        )
                    }
                    .padding()
                    .background(Color(.gray).opacity(0.1))
                    .cornerRadius(12)
                    
                    // Refresh Button
                    Button(action: {
                        Task {
                            await viewModel.refresh()
                        }
                    }) {
                        HStack {
                            if viewModel.isRefreshing {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "arrow.clockwise")
                            }
                            Text(viewModel.isRefreshing ? "Refreshing..." : "Refresh Configuration")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .disabled(viewModel.isRefreshing)
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Remote Config")
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
