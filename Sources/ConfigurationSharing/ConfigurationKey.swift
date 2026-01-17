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
/// The key automatically observes the default configuration reader for changes and updates
/// the shared value when the underlying configuration changes.
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
        guard let value = try? readValue() else {
            continuation.resumeReturningInitialValue()
            return
        }
        continuation.resume(with: .success(value))
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
                    // Something like
                    @Dependency(\.defaultConfigurationReader) var defaultReader
                    resolvedReader = try await defaultReader.initialize()
                }
                try await resolvedReader.watchSnapshot { updates in
                    for await snapshot in updates {
                        // Read the value from the snapshot
                        if let result = try? snapshot.value(
                            forKey: Configuration.AbsoluteConfigKey(stringLiteral: key),
                            type: configType(for: Value.self)
                        ),
                           let extractedValue = extractValue(from: result) {
                            subscriber.yield(with: .success(extractedValue))
                        }
                    }
                }
            } catch {
                // If watching fails, stick with current value
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
    
    // private func readValue() throws -> Value? {
    //     let result = try reader?.value(
    //         forKey: Configuration.AbsoluteConfigKey(stringLiteral: key),
    //         type: configType(for: Value.self)
    //     )
    //     return extractValue(from: result)
    // }
    
    private func extractValue(from result: Configuration.LookupResult) -> Value? {
        guard let configValue = result.value else {
            return nil
        }
        
        // Extract the actual value based on type using ConfigContent pattern matching
        if Value.self == String.self {
            guard case .string(let value) = configValue.content else { return nil }
            return value as? Value
        } else if Value.self == Int.self {
            guard case .int(let value) = configValue.content else { return nil }
            return value as? Value
        } else if Value.self == Double.self {
            guard case .double(let value) = configValue.content else { return nil }
            return value as? Value
        } else if Value.self == Bool.self {
            guard case .bool(let value) = configValue.content else { return nil }
            return value as? Value
        } else if Value.self == [String].self {
            guard case .stringArray(let value) = configValue.content else { return nil }
            return value as? Value
        } else {
            return nil
        }
    }
    
    private func configType(for type: Any.Type) -> Configuration.ConfigType {
        if type == String.self {
            return .string
        } else if type == Int.self {
            return .int
        } else if type == Double.self {
            return .double
        } else if type == Bool.self {
            return .bool
        } else if type == [String].self {
            return .stringArray
        } else {
            return .string // Default fallback
        }
    }
}

/// Identifier for configuration keys
public struct ConfigurationKeyID: Hashable {
    let key: String
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
/