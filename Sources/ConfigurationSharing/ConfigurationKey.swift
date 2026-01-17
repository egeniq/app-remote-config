import Configuration
import Dependencies
import Foundation
import Sharing

/// A sharing key that reads and observes values from a `ConfigReader`.
///
/// This key integrates the Swift Configuration library with the Swift Sharing library,
/// allowing you to use `@SharedReader` properties backed by a configuration reader.
///
/// Example usage:
/// ```swift
/// @SharedReader(.configuration("apiEndpoint"))
/// var apiEndpoint = "https://api.example.com"
///
/// @SharedReader(.configuration("timeout"))
/// var timeout = 30
///
/// @SharedReader(.configuration("features.betaMode"))
/// var betaMode = false
/// ```
///
/// The key fetches an initial value asynchronously from the configuration reader and then
/// observes it for changes, updating the shared value when the underlying configuration changes.
///
/// Note: Configuration is read-only, so only `@SharedReader` is supported.
public struct ConfigurationKey<Value: Sendable>: SharedReaderKey {
    private let key: String
    private let reader: ConfigReader?
    
    public var id: ConfigurationKeyID {
        ConfigurationKeyID(key: key, reader: reader)
    }
    
    /// Creates a configuration key that reads from the default configuration provider.
    ///
    /// - Parameters:
    ///   - key: The configuration key path (dot-separated for nested values)
    public init(_ key: String) where Value: ConfigPrimitiveValue {
        self.key = key
        self.reader = nil
    }
    
    /// Creates a configuration key that reads from a specific configuration reader.
    ///
    /// - Parameters:
    ///   - key: The configuration key path (dot-separated for nested values)
    ///   - reader: The configuration reader to read from
    public init(_ key: String, reader: ConfigReader?) where Value: ConfigPrimitiveValue {
        self.key = key
        self.reader = reader
    }
    
    public func load(context: LoadContext<Value>, continuation: LoadContinuation<Value>) {
        // Use the continuation to fetch the initial value asynchronously.
        // We spawn a Task that initializes the reader and fetches the first value,
        // then resume the continuation with it.
        Task {
            do {
                let resolvedReader: ConfigReader
                if let reader = reader {
                    resolvedReader = reader
                } else {
                    @Dependency(\.defaultConfigurationReader) var defaultReader
                    resolvedReader = try await defaultReader.initialize()
                }
                
                // Get the snapshot and read the current value
                let snapshot = resolvedReader.snapshot()
                if let extractedValue = extractValue(
                    from: snapshot,
                    for: Value.self,
                    key: key
                ) {
                    continuation.resume(with: .success(extractedValue))
                } else {
                    continuation.resumeReturningInitialValue()
                }
            } catch {
                // If initialization fails, use the default from context
                continuation.resumeReturningInitialValue()
            }
        }
    }
    
    public func subscribe(
        context: LoadContext<Value>,
        subscriber: SharedSubscriber<Value>
    ) -> SharedSubscription {
        let task = Task {
            do {
                let resolvedReader: ConfigReader
                if let reader = reader {
                    resolvedReader = reader
                } else {
                    @Dependency(\.defaultConfigurationReader) var defaultReader
                    resolvedReader = try await defaultReader.initialize()
                }
                
                try await resolvedReader.watchSnapshot { updates in
                    for await snapshot in updates {
                        // Read the value from the snapshot using the appropriate method
                        if let extractedValue = extractValue(
                            from: snapshot,
                            for: Value.self,
                            key: key
                        ) {
                            subscriber.yield(with: .success(extractedValue))
                        }
                    }
                }
            } catch {
                // If watching fails, the value stays at its initial state
            }
        }
        
        return SharedSubscription {
            task.cancel()
        }
    }
    
    /// Write operations are not supported for configuration values (read-only).
    /// This method is provided for `SharedReaderKey` conformance but does nothing.
    public func set(_ value: Value, context: LoadContext<Value>) {
        // Configuration is read-only, so writes are ignored
    }
    
    private func extractValue(
        from snapshot: Configuration.ConfigSnapshotReader,
        for type: Any.Type,
        key: String
    ) -> Value? {
        let configKey = Configuration.ConfigKey(stringLiteral: key)
        
        // Read the appropriate type from the snapshot using the public API
        if type == String.self {
            return snapshot.string(forKey: configKey) as? Value
        } else if type == Int.self {
            return snapshot.int(forKey: configKey) as? Value
        } else if type == Double.self {
            return snapshot.double(forKey: configKey) as? Value
        } else if type == Bool.self {
            return snapshot.bool(forKey: configKey) as? Value
        } else if type == [String].self {
            return snapshot.stringArray(forKey: configKey) as? Value
        } else {
            return nil
        }
    }
}

/// Identifier for configuration keys
public struct ConfigurationKeyID: Hashable {
    public let key: String
    // let providerName: String
    
    init(key: String, reader: ConfigReader?) {
        self.key = key
        // self.providerName = reader.
    }
}

/// Marker protocol to constrain supported configuration value types
public protocol ConfigPrimitiveValue: Sendable {}

extension String: ConfigPrimitiveValue {}
extension Int: ConfigPrimitiveValue {}
extension Double: ConfigPrimitiveValue {}
extension Bool: ConfigPrimitiveValue {}
extension Array: ConfigPrimitiveValue where Element == String {}

/// Extension to make ConfigurationKey more ergonomic to use
extension SharedReaderKey where Self == ConfigurationKey<String> {
    /// Creates a configuration key for a string value.
    public static func configuration(_ key: String) -> Self {
        ConfigurationKey(key)
    }
    
    /// Creates a configuration key for a string value with a specific reader.
    public static func configuration(_ key: String, reader: ConfigReader?) -> Self {
        ConfigurationKey(key, reader: reader)
    }
}

extension SharedReaderKey where Self == ConfigurationKey<Int> {
    /// Creates a configuration key for an integer value.
    public static func configuration(_ key: String) -> Self {
        ConfigurationKey(key)
    }
    
    /// Creates a configuration key for a string value with a specific reader.
    public static func configuration(_ key: String, reader: ConfigReader?) -> Self {
        ConfigurationKey(key, reader: reader)
    }
}

extension SharedReaderKey where Self == ConfigurationKey<Double> {
    /// Creates a configuration key for a double value.
    public static func configuration(_ key: String) -> Self {
        ConfigurationKey(key)
    }
    
    /// Creates a configuration key for a string value with a specific reader.
    public static func configuration(_ key: String, reader: ConfigReader?) -> Self {
        ConfigurationKey(key, reader: reader)
    }
}

extension SharedReaderKey where Self == ConfigurationKey<Bool> {
    /// Creates a configuration key for a boolean value.
    public static func configuration(_ key: String) -> Self {
        ConfigurationKey(key)
    }
    
    /// Creates a configuration key for a string value with a specific reader.
    public static func configuration(_ key: String, reader: ConfigReader?) -> Self {
        ConfigurationKey(key, reader: reader)
    }
}

extension SharedReaderKey where Self == ConfigurationKey<[String]> {
    /// Creates a configuration key for a string array value.
    public static func configuration(_ key: String) -> Self {
        ConfigurationKey(key)
    }
    
    /// Creates a configuration key for a string value with a specific reader.
    public static func configuration(_ key: String, reader: ConfigReader?) -> Self {
        ConfigurationKey(key, reader: reader)
    }
}
