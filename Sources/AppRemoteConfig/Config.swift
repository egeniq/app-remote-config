import Foundation

/// A simple but effective way to manage apps remotely. A simple configuration file that is easy to maintain and host, yet provides important flexibility to specify settings based on your needs.
public struct Config {
    /// The default settings that an app should use.
    public let settings: [String: Any]
    
    /// Keys that are no longer in use, but may still be used by overrides to accomodate older versions of an app.
    public let deprecatedKeys: [String]
    
    /// Overrides containing the settings to apply when they match and/or are scheduled. Applied from top to bottom.
    public let overrides: [Override]
    
    /// Store metadata such as author or last updated date here.
    public let meta: [String: Any]
    
    /// Create a config from a JSON like structure
    /// - Parameter json: JSON descibing the desired configuration according to this [scheme](https://raw.githubusercontent.com/egeniq/app-remote-config/main/Schema/appremoteconfig.schema.json)
    public init(json: [String: Any]) throws {
        if let jsonValue = json["settings"] {
            guard let dictionary = jsonValue as? [String: Any] else {
                throw ConfigError.unexpectedTypeForKey("settings")
            }
            settings = dictionary
        } else {
            settings = [:]
        }
        deprecatedKeys = json["deprecatedKeys"] as? [String] ?? []
        overrides = (json["overrides"] as? [[String: Any]])?.map(Override.init(json:)) ?? []
        meta = json["meta"] as? [String: Any] ?? [:]
    }
}
