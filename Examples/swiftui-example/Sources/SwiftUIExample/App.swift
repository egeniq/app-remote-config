import SwiftUI
import Foundation
import AppRemoteConfigProvider
import AppRemoteConfig
import Configuration

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
    
    /// Initialize the view model with example configuration
    private func initializeProvider() async {
        do {
            // Simulate async initialization
            try await Task.sleep(nanoseconds: 500_000_000)
            
            // Create a view model with example data
            // In a real app, you would initialize AppRemoteConfigProvider here
            // and pass it to ContentViewViewModel
            await MainActor.run {
                self.viewModel = ContentViewViewModel.mockViewModel()
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
