import Foundation

public struct Version: Equatable, Comparable {
    public static func < (lhs: Version, rhs: Version) -> Bool {
        if lhs.canonical.0 == rhs.canonical.0 && lhs.canonical.1 == rhs.canonical.1 {
            lhs.canonical.2 < rhs.canonical.2
        } else if lhs.canonical.0 == rhs.canonical.0 {
            lhs.canonical.1 < rhs.canonical.1
        } else {
            lhs.canonical.0 < rhs.canonical.0
        }
    }
    
    public static func == (lhs: Version, rhs: Version) -> Bool {
        lhs.canonical.0 == rhs.canonical.0 &&
        lhs.canonical.1 == rhs.canonical.1 &&
        lhs.canonical.2 == rhs.canonical.2
    }
    
    var canonical: (Int, Int, Int)
    
    public var rawValue: String {
        "\(canonical.0).\(canonical.1).\(canonical.2)"
    }
    
    public init(_ rawValue: String) throws {
        #if os(Android)
        var trimmedValue = rawValue
        trimmedValue
            .trimPrefix(while: { !"1234567890.".contains($0) })
        #else
        let trimmedValue = rawValue
            .trimmingCharacters(in: CharacterSet(charactersIn: "1234567890.").inverted)
        #endif
        let parts = trimmedValue
            .split(separator: ".")
            .compactMap { Int($0) }
            .prefix(3)
        guard parts.count >= 1 else {
            throw ConfigError.nonSemanticVersion
        }
        let padded = parts + Array(repeating: 0, count: max(3 - parts.count, 0))
        canonical = (padded[0], padded[1], padded[2])
    }
    
    public init(_ version: OperatingSystemVersion) {
        canonical = (version.majorVersion, version.minorVersion, version.patchVersion)
    }
    
    public var operatingSystemVersion: OperatingSystemVersion {
        .init(majorVersion: canonical.0, minorVersion: canonical.1, patchVersion: canonical.2)
    }
}


public struct OperatingSystemVersion {
    let majorVersion: Int
    let minorVersion: Int
    let patchVersion: Int
}
