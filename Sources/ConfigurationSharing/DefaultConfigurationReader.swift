import Configuration
import Dependencies
import Foundation
import Logging
import ServiceLifecycle

/// A default configuration provider dependency with async initialization support.
///
/// Most configuration providers have async initializers, so this dependency provides
/// a factory pattern that allows you to set up the initialization logic in
/// `prepareDependencies` (which is synchronous) and then call it asynchronously
/// when needed.
///
/// The reader is cached after the first initialization, so subsequent calls return
/// the same instance. If the provider conforms to `Service`, it will be automatically
/// managed in a ServiceGroup.
///
/// Example usage:
/// ```swift
/// @main
/// struct MyApp: App {
///     init() {
///         prepareDependencies {
///             $0.defaultConfigurationReader.initialize = {
///                 var logger = Logger(label: "com.example.config")
///                 logger.logLevel = .debug
///                 
///                 let provider = try await AppRemoteConfigProvider(
///                     url: configURL,
///                     pollInterval: .seconds(30),
///                     resolutionContext: context,
///                     logger: logger
///                 )
///                 
///                 return (ConfigReader(providers: [provider]), logger)
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
    /// Async initialization function that creates and returns a configuration reader and optional logger.
    /// If a logger is provided, it will be used for any internal service lifecycle management.
    public var initialize: @Sendable () async throws -> (ConfigReader, Logger?)
    
    public init(initialize: @escaping @Sendable () async throws -> (ConfigReader, Logger?)) {
        let cache = ReaderCache()
        self.initialize = {
            try await cache.getOrInitialize(with: initialize)
        }
    }
}

/// Internal actor for caching the initialized ConfigReader to ensure it's created only once.
private actor ReaderCache {
    private var cachedReader: ConfigReader?
    
    func getOrInitialize(
        with factory: @escaping @Sendable () async throws -> (ConfigReader, Logger?)
    ) async throws -> (ConfigReader, Logger?) {
        // Return cached reader if available
        if let cached = cachedReader {
            return (cached, nil)
        }
        
        // Initialize via factory and cache the result
        let (reader, logger) = try await factory()
        cachedReader = reader
        
        return (reader, logger)
    }
}

extension DependencyValues {
    /// The default configuration reader factory for async initialization.
    ///
    /// Set this in `prepareDependencies` to provide a factory function that creates
    /// your configuration reader asynchronously.
    ///
    /// Example:
    /// ```swift
    /// prepareDependencies {
    ///     $0.defaultConfigurationReader.initialize = {
    ///         var logger = Logger(label: "com.example.config")
    ///         let provider = try await YourConfigProvider(logger: logger)
    ///         return (ConfigReader(providers: [provider]), logger)
    ///     }
    /// }
    /// ```
    public var defaultConfigurationReader: DefaultConfigurationReader {
        get { self[DefaultConfigurationReaderKey.self] }
        set { self[DefaultConfigurationReaderKey.self] = newValue }
    }
}

private enum DefaultConfigurationReaderKey: DependencyKey {
    static let liveValue = DefaultConfigurationReader {
        fatalError(
            """
            No default configuration reader has been configured.
            
            Set one in prepareDependencies:
            
                prepareDependencies {
                    $0.defaultConfigurationReader.initialize = {
                        var logger = Logger(label: "com.app.config")
                        let provider = try await YourConfigProvider(logger: logger)
                        return (ConfigReader(providers: [provider]), logger)
                    }
                }
            """
        )
    }
    
    static let testValue = DefaultConfigurationReader {
        fatalError(
            """
            Unimplemented: @Dependency(\\.defaultConfigurationReader)
            
            Provide a test reader:
            
                withDependencies {
                    $0.defaultConfigurationReader.initialize = {
                        (ConfigReader(providers: []), nil)
                    }
                } operation: {
                    // Test code here
                }
            """
        )
    }
}
