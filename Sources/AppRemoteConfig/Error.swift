import Foundation

public enum ConfigError: Error, Equatable {
    case nonSemanticVersion
    case invalidVersionRange
    case unexpectedTypeForKey(String)
    case base64DecodingFailed
    case invalidSignature
    case signingFailed
}
