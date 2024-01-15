import Foundation

public enum ConfigError: Error {
    case nonSemanticVersion
    case invalidVersionRange
    case unexpectedTypeForKey(String)
}
