import Configuration
import Dependencies
import Foundation
import Sharing

/// A sharing key that reads and observes values from a `ConfigProvider`.
///
/// This key integrates the Swift Configuration library with the Swift Sharing library,
/// allowing you to use `@SharedReader` properties backed by configuration providers.
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
/// The key automatically observes the configuration provider for changes and updates
/// the shared value when the underlying configuration changes.
///
/// Note: Configuration is read-only, so only `@SharedReader` is supported.
public struct ConfigurationKey<Value: Sendable>: SharedReaderKey {
    private let key: String
    private let provider: any ConfigProvider
    
    public var id: ConfigurationKeyID {
        ConfigurationKeyID(key: key, provider: provider)
    }
    
    /// Creates a configuration key that reads from the default configuration provider.
    ///
    /// - Parameters:
    ///   - key: The configuration key path (dot-separated for nested values)
    public init(_ key: String) where Value: ConfigPrimitiveValue {
        self.key = key
        @Dependency(\.defaultConfigurationProvider) var provider
        self.provider = provider
    }
    
    /// Creates a configuration key that reads from a specific configuration provider.
    ///
    /// - Parameters:
    ///   - key: The configuration key path (dot-separated for nested values)
    ///   - provider: The configuration provider to read from
    public init(_ key: String, provider: any ConfigProvider) where Value: ConfigPrimitiveValue {
        self.key = key
        self.provider = provider
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
                try await provider.watchSnapshot { updates in
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
    
    private func readValue() throws -> Value? {
        let result = try provider.value(
            forKey: Configuration.AbsoluteConfigKey(stringLiteral: key),
            type: configType(for: Value.self)
        )
        return extractValue(from: result)
    }
    
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
    let providerName: String
    
    init(key: String, provider: any ConfigProvider) {
        self.key = key
        self.providerName = provider.providerName
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
    
    /// Creates a configuration key for a string value with a specific provider.
    public static func configuration(_ key: String, provider: any ConfigProvider) -> Self {
        ConfigurationKey(key, provider: provider)
    }
}

extension SharedReaderKey where Self == ConfigurationKey<Int> {
    /// Creates a configuration key for an integer value.
    public static func configuration(_ key: String) -> Self {
        ConfigurationKey(key)
    }
    
    /// Creates a configuration key for an integer value with a specific provider.
    public static func configuration(_ key: String, provider: any ConfigProvider) -> Self {
        ConfigurationKey(key, provider: provider)
    }
}

extension SharedReaderKey where Self == ConfigurationKey<Double> {
    /// Creates a configuration key for a double value.
    public static func configuration(_ key: String) -> Self {
        ConfigurationKey(key)
    }
    
    /// Creates a configuration key for a double value with a specific provider.
    public static func configuration(_ key: String, provider: any ConfigProvider) -> Self {
        ConfigurationKey(key, provider: provider)
    }
}

extension SharedReaderKey where Self == ConfigurationKey<Bool> {
    /// Creates a configuration key for a boolean value.
    public static func configuration(_ key: String) -> Self {
        ConfigurationKey(key)
    }
    
    /// Creates a configuration key for a boolean value with a specific provider.
    public static func configuration(_ key: String, provider: any ConfigProvider) -> Self {
        ConfigurationKey(key, provider: provider)
    }
}

extension SharedReaderKey where Self == ConfigurationKey<[String]> {
    /// Creates a configuration key for a string array value.
    public static func configuration(_ key: String) -> Self {
        ConfigurationKey(key)
    }
    
    /// Creates a configuration key for a string array value with a specific provider.
    public static func configuration(_ key: String, provider: any ConfigProvider) -> Self {
        ConfigurationKey(key, provider: provider)
    }
}

/// A default configuration provider dependency.
///
/// Example:
/// ```swift
/// // At app startup:
/// prepareDependencies {
///     $0.defaultConfigurationProvider = myConfigProvider
/// }
///
/// // Later, anywhere in the app:
/// @Shared(.configuration("apiEndpoint", default: "https://api.example.com"))
/// var apiEndpoint: String
/// ```
private enum DefaultConfigurationProviderKey: DependencyKey {
    static var liveValue: any ConfigProvider {
        EmptyConfigProvider()
    }
    static var previewValue: any ConfigProvider {
        EmptyConfigProvider()
    }
    static var testValue: any ConfigProvider {
        EmptyConfigProvider()
    }
}

extension DependencyValues {
    /// The default configuration provider used by ConfigurationKey.
    ///
    /// Set this at app startup to provide a default configuration provider for all
    /// `@Shared(.configuration(...))` instances that don't specify an explicit provider.
    public var defaultConfigurationProvider: any ConfigProvider {
        get { self[DefaultConfigurationProviderKey.self] }
        set { self[DefaultConfigurationProviderKey.self] = newValue }
    }
}

/// A placeholder config provider used when no default is set
private struct EmptyConfigProvider: ConfigProvider {
    var providerName: String { "EmptyConfigProvider" }
    
    func value(forKey key: Configuration.AbsoluteConfigKey, type: Configuration.ConfigType) throws -> Configuration.LookupResult {
        return Configuration.LookupResult(encodedKey: key.description, value: nil)
    }
    
    func fetchValue(forKey key: Configuration.AbsoluteConfigKey, type: Configuration.ConfigType) async throws -> Configuration.LookupResult {
        return Configuration.LookupResult(encodedKey: key.description, value: nil)
    }
    
    func watchValue<Return: ~Copyable>(
        forKey key: Configuration.AbsoluteConfigKey,
        type: Configuration.ConfigType,
        updatesHandler: nonisolated(nonsending) (Configuration.ConfigUpdatesAsyncSequence<Result<Configuration.LookupResult, any Error>, Never>) async throws -> Return
    ) async throws -> Return {
        let (stream, _) = AsyncStream<Result<Configuration.LookupResult, any Error>>.makeStream()
        return try await updatesHandler(.init(stream))
    }
    
    func snapshot() -> any Configuration.ConfigSnapshot {
        EmptySnapshot()
    }
    
    func watchSnapshot<Return: ~Copyable>(
        updatesHandler: nonisolated(nonsending) (Configuration.ConfigUpdatesAsyncSequence<any Configuration.ConfigSnapshot, Never>) async throws -> Return
    ) async throws -> Return {
        let (stream, _) = AsyncStream<any Configuration.ConfigSnapshot>.makeStream()
        return try await updatesHandler(.init(stream))
    }
}

private struct EmptySnapshot: Configuration.ConfigSnapshot {
    var description: String { "{}" }
    var debugDescription: String { "{}" }
    var providerName: String { "EmptySnapshot" }
    
    func value(forKey key: Configuration.AbsoluteConfigKey, type: Configuration.ConfigType) throws -> Configuration.LookupResult {
        return Configuration.LookupResult(encodedKey: key.description, value: nil)
    }
}

