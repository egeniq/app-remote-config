import Foundation

/// Is the app compiled for debugging or for release?
public enum BuildVariant: String, CaseIterable, Sendable {
    case release
    case debug
    case unknown
}
