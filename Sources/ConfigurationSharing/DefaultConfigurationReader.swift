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
/// the same instance. If services are provided, they are automatically managed in a
/// ServiceGroup for lifecycle management.
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
///                 // Return reader, services to manage, and logger
///                 return (ConfigReader(providers: [provider]), [provider], logger)
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
    /// Returns a tuple of (ConfigReader, services to manage, optional logger).
    /// If services are provided, they will be managed in a ServiceGroup using the logger.
    public var initialize: @Sendable () async throws -> (ConfigReader, [any Service]?, Logger?)
    
    public init(initialize: @escaping @Sendable () async throws -> (ConfigReader, [any Service]?, Logger?)) {
        let cache = ReaderCache()
        self.initialize = {
            try await cache.getOrInitialize(with: initialize)
        }
    }
}

/// Internal actor for managing the initialized ConfigReader and its services.
private actor ReaderCache {
    private var cachedReader: ConfigReader?
    private var serviceGroup: ServiceGroup?
    
    func getOrInitialize(
        with factory: @escaping @Sendable () async throws -> (ConfigReader, [any Service]?, Logger?)
    ) async throws -> (ConfigReader, [any Service]?, Logger?) {
        // Return cached reader if available
        if let cached = cachedReader {
            return (cached, nil, nil)
        }
        
        // Initialize via factory
        let (reader, services, logger) = try await factory()
        cachedReader = reader
        
        // If services are provided, manage them in a ServiceGroup
        if let services = services, !services.isEmpty {
            let group = ServiceGroup(services: services, logger: logger ?? Logger(label: "ConfigurationSharing"))
            self.serviceGroup = group
            
            // Run the service group in the background
            Task.detached(priority: .userInitiated) {
                do {
                    try await group.run()
                } catch {
                    // Log but don't fail - configuration reader still works
                    if let logger = logger {
                        logger.error("ServiceGroup error: \(error)")
                    }
                }
            }
        }
        
        return (reader, services, logger)
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
    ///         // Pass services that conform to Service for lifecycle management
    ///         return (ConfigReader(providers: [provider]), [provider], logger)
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
                        return (ConfigReader(providers: [provider]), [provider], logger)
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
                        (ConfigReader(providers: []), nil, nil)
                    }
                } operation: {
                    // Test code here
                }
            """
        )
    }
}
