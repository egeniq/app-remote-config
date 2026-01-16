import SwiftUI
import Configuration
import AppRemoteConfigProvider

/// View model that reads configuration values and exposes them to SwiftUI
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
    
    private let provider: AppRemoteConfigProvider<JSONSnapshot>?
    
    init(provider: AppRemoteConfigProvider<JSONSnapshot>?) {
        self.provider = provider
        loadConfiguration()
    }
    
    /// Create a view model with example data for demonstration
    static func mockViewModel() -> ContentViewViewModel {
        let viewModel = ContentViewViewModel(provider: nil)
        viewModel.appName = "Remote Config Example"
        viewModel.betaMode = true
        viewModel.newUIEnabled = true
        viewModel.darkModeEnabled = true
        viewModel.apiEndpoint = "https://api.example.com"
        viewModel.timeout = 30
        viewModel.maxRetries = 3
        return viewModel
    }
    
    /// Load all configuration values from the provider
    func loadConfiguration() {
        guard let provider = provider else {
            // If no provider, set example values
            appName = "Remote Config Example"
            betaMode = true
            newUIEnabled = true
            darkModeEnabled = true
            apiEndpoint = "https://api.example.com"
            timeout = 30
            maxRetries = 3
            return
        }
        
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
        
        guard let provider = provider else {
            return
        }
        
        do {
            try await provider.refresh()
            loadConfiguration()
        } catch {
            print("Failed to refresh configuration: \(error)")
        }
    }
}
