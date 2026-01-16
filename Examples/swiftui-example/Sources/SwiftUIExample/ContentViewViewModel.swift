import SwiftUI
import Configuration
import AppRemoteConfigProvider

/// View model that reads configuration values and exposes them to SwiftUI
@available(iOS 18.0, *)
@MainActor
class ContentViewViewModel: ObservableObject {
    @Published var appName: String = "Loading..."
    @Published var betaMode: Bool = false
    @Published var newUIEnabled: Bool = false
    @Published var darkModeEnabled: Bool = false
    @Published var apiEndpoint: String = "Loading..."
    @Published var timeout: Int = 0
    @Published var maxRetries: Int = 0
    @Published var isRefreshing: Bool = false
    
    private let provider: AppRemoteConfigProvider<JSONSnapshot>
    private var snapshotWatcherTask: Task<Void, Never>?
    
    init(provider: AppRemoteConfigProvider<JSONSnapshot>) {
        self.provider = provider
        loadConfiguration()
        startWatchingSnapshot()
    }
    
    /// Watch the snapshot for changes and reload when it updates
    private func startWatchingSnapshot() {
        snapshotWatcherTask = Task {
            do {
                try await provider.watchSnapshot { @Sendable updates in
                    for await _ in updates {
                        // Snapshot changed, reload configuration
                        await MainActor.run {
                            self.loadConfiguration()
                        }
                    }
                }
            } catch {
                print("Error watching snapshot: \(error)")
            }
        }
    }
    
    /// Load all configuration values from the provider
    func loadConfiguration() {
        let reader = ConfigReader(provider: provider)
        
        // Read individual configuration values with defaults
        appName = reader.string(forKey: "appName", default: "Unknown App")
        betaMode = reader.bool(forKey: "features.betaMode", default: false)
        newUIEnabled = reader.bool(forKey: "features.newUI", default: false)
        darkModeEnabled = reader.bool(forKey: "features.darkMode", default: false)
        apiEndpoint = reader.string(forKey: "apiEndpoint", default: "https://default.example.com")
        timeout = reader.int(forKey: "timeout", default: 30)
        maxRetries = reader.int(forKey: "maxRetries", default: 3)
    }
    
    /// Manually refresh configuration from the source
    func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }
        
        do {
            try await provider.refresh()
            loadConfiguration()
        } catch {
            print("Failed to refresh configuration: \(error)")
        }
    }
    
    deinit {
        snapshotWatcherTask?.cancel()
    }
}
