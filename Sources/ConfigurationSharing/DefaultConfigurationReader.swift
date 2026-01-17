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
///             $0.defaultConfigurationReader.initialize = {
///                 try await AppRemoteConfigProvider(
///                     url: configURL,
///                     pollInterval: .seconds(30),
///                     resolutionContext: context,
///                     logger: logger
///                 )
///                 return ConfigReader(providers: [provider])
///             }
///         }
///     }
///
///     var body: some Scene {
///         WindowGroup {
///             ContentView()
///         }
///     }
/// }
/// ```
public struct DefaultConfigurationReader: Sendable {
    /// Async initialization function that creates and returns a configuration reader.
    public var initialize: @Sendable () async throws -> ConfigReader
    
    public init(initialize: @escaping @Sendable () async throws -> ConfigReader) {
        self.initialize = initialize

        // TODO: Caching the initialized reader here
        // TODO: Wrap the ConfigReader in a ServiceGroup for lifecycle management
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
    ///     $0.defaultConfigurationReader.initialize = {
    ///         let provider = try await YourConfigProvider()
    ///         return ConfigReader(providers: [provider])
    ///     }
    /// }
    /// ```
    public var defaultConfigurationReader: DefaultConfigurationReader {
        get { self[DefaultConfigurationReaderKey.self] }
        set { self[DefaultConfigurationReaderKey.self] = newValue }
    }
}

// BELOW IS INCORRECT
// private enum DefaultConfigurationReaderKey: DependencyKey {
//     static let liveValue = DefaultConfigurationReader {
//         fatalError(
//             """
//             No default configuration provider has been configured.
            
//             Set one in prepareDependencies:
            
//                 prepareDependencies {
//                     $0.defaultConfigurationProvider.initialize = {
//                         try await YourConfigProvider(/* ... */)
//                     }
//                 }
//             """
//         )
//     }
    
//     static let testValue = DefaultConfigurationReader {
//         fatalError(
//             """
//             Unimplemented: @Dependency(\\.defaultConfigurationReader)
            
//             Provide a test reader:
            
//                 withDependencies {
//                     $0.defaultConfigurationReader.initialize = {
//                         MockConfigReader()
//                     }
//                 } operation: {
//                     // Test code here
//                 }
//             """
//         )
//     }
// }
