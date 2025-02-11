import Dependencies
import Foundation
import SodiumClient

/// A simple but effective way to manage apps remotely. A simple configuration file that is easy to maintain and host, yet provides important flexibility to specify settings based on your needs.
public struct Config: Sendable {
    /// The default settings that an app should use.
    public let settings: [String: Sendable]
    
    /// Keys that are no longer in use, but may still be used by overrides to accomodate older versions of an app.
    public let deprecatedKeys: [String]
    
    /// Overrides containing the settings to apply when they match and/or are scheduled. Applied from top to bottom.
    public let overrides: [Override]
    
    /// Store metadata such as author or last updated date here.
    public let meta: [String: Sendable]
    
    /// Create a config from a JSON like structure
    /// - Parameter json: JSON describing the desired configuration according to this [scheme](https://raw.githubusercontent.com/egeniq/app-remote-config/main/Schema/appremoteconfig.schema.json)
    public init(json: [String: Sendable]) throws {
        if let jsonValue = json["settings"] {
            guard let dictionary = jsonValue as? [String: Sendable] else {
                throw ConfigError.unexpectedTypeForKey("settings")
            }
            settings = dictionary
        } else {
            settings = [:]
        }
        deprecatedKeys = json["deprecatedKeys"] as? [String] ?? []
        overrides = (json["overrides"] as? [[String: Sendable]])?.map(Override.init(json:)) ?? []
        meta = json["meta"] as? [String: Sendable] ?? [:]
    }
    
    /// Create a config from JSON
    /// - Parameter data: Data containing JSON describing the desired configuration according to this [scheme](https://raw.githubusercontent.com/egeniq/app-remote-config/main/Schema/appremoteconfig.schema.json)
    public init(data: Data) throws {
        guard let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Sendable] else {
            throw ConfigError.unexpectedTypeForKey("root")
        }
        try self.init(json: json)
    }
  
#if canImport(Sodium)
    /// Create a config from signed JSON
    /// - Parameters:
    ///   - data: Data containing signed JSON describing the desired configuration according to this [scheme](https://raw.githubusercontent.com/egeniq/app-remote-config/main/Schema/appremoteconfig.schema.json)
    ///   - publicKey: Base64 encoded public key that was used to sign the data.
    public init(data: Data, publicKey: String) throws {
        @Dependency(SodiumClient.self) var sodiumClient
        guard let config = sodiumClient.open(signedMessage: data, publicKey: publicKey) else {
            throw ConfigError.invalidSignature
        }
        guard let json = try JSONSerialization.jsonObject(with: config, options: []) as? [String: Sendable] else {
            throw ConfigError.unexpectedTypeForKey("root")
        }
        try self.init(json: json)
    }
#endif
}
