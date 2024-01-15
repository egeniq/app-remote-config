import Foundation

public struct Config {
    public var settings: [String: Any]
    public var deprecatedKeys: [String]
    public var overrides: [Override]
    public var meta: [String: Any]
    
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
