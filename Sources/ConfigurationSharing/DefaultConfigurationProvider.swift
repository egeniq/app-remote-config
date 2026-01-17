import Configuration
import Dependencies
import Foundation

/// A default configuration provider dependency with async initialization support.
///
/// Most configuration providers have async initializers, so this dependency provides
/// a factory pattern that allows you to set up the initialization logic in
/// `prepareDependencies` (which is synchronous) and then call it asynchronously
/// when needed.
///
/// Example usage:
/// ```swift
/// @main
/// struct MyApp: App {
///     init() {
///         prepareDependencies {
///             $0.defaultConfigurationProvider.initialize = {
///                 try await AppRemoteConfigProvider(
///                     url: configURL,
///                     pollInterval: .seconds(30),
///                     resolutionContext: context,
///                     logger: logger
///                 )
///             }
///         }
///     }
///
///     var body: some Scene {
///         WindowGroup {
///             ContentView()
///                 .task {
///                     await initializeConfiguration()
///                 }
///         }
///     }
///
///     private func initializeConfiguration() async {
///         @Dependency(\.defaultConfigurationProvider) var providerDep
///         do {
///             let provider = try await providerDep.initialize()
///             withDependencies {
///                 $0.configProvider = provider
///             } operation: {
///                 // Provider is now available for @Shared(.configuration(...))
///             }
///         } catch {
///             // Handle initialization error
///         }
///     }
/// }
/// ```
public struct DefaultConfigurationProvider: Sendable {
    /// Async initialization function that creates and returns a configuration provider.
    public var initialize: @Sendable () async throws -> any ConfigProvider
    
    public init(initialize: @escaping @Sendable () async throws -> any ConfigProvider) {
        self.initialize = initialize
    }
}

extension DependencyValues {
    /// The default configuration provider factory for async initialization.
    ///
    /// Set this in `prepareDependencies` to provide a factory function that creates
    /// your configuration provider asynchronously.
    ///
    /// Example:
    /// ```swift
    /// prepareDependencies {
    ///     $0.defaultConfigurationProvider.initialize = {
    ///         try await YourConfigProvider(/* ... */)
    ///     }
    /// }
    /// ```
    public var defaultConfigurationProvider: DefaultConfigurationProvider {
        get { self[DefaultConfigurationProviderKey.self] }
        set { self[DefaultConfigurationProviderKey.self] = newValue }
    }
}

private enum DefaultConfigurationProviderKey: DependencyKey {
    static let liveValue = DefaultConfigurationProvider {
        fatalError(
            """
            No default configuration provider has been configured.
            
            Set one in prepareDependencies:
            
                prepareDependencies {
                    $0.defaultConfigurationProvider.initialize = {
                        try await YourConfigProvider(/* ... */)
                    }
                }
            """
        )
    }
    
    static let testValue = DefaultConfigurationProvider {
        fatalError(
            """
            Unimplemented: @Dependency(\\.defaultConfigurationProvider)
            
            Provide a test provider:
            
                withDependencies {
                    $0.defaultConfigurationProvider.initialize = {
                        MockConfigProvider()
                    }
                } operation: {
                    // Test code here
                }
            """
        )
    }
}
