import Foundation

/// Range of versions
public enum VersionRange {
    
    /// Matches an exact version
    /// 
    /// Example string representation: \
    /// `1.0.0`
    case equal(Version)
    
    /// Matches a version lesser than the given version, if the boolean is `true` the version is included
    ///
    /// Example string representations: \
    /// `<1.0.0` '
    /// `<=1.0.0`
    case lesserThan((Version, Bool))
    
    /// Matches a version greater than the given version, if the boolean is `true` the version is included
    ///
    /// Example string representations: \
    /// `>1.0.0` \
    /// `>=1.0.0`
    case greaterThan((Version, Bool))
    
    /// Matches a version between two given versions, if the boolean is `true` the version is included
    ///
    /// Example string representations: \
    /// `1.0.0-2.0.0` (versions 1.0.0 and 2.0.0 are included) \
    /// `1.0.0>-2.0.0`(version 1.0.0 excluded and version 2.0.0 included) \
    /// `1.0.0-<2.0.0`(version 1.0.0 included and version 2.0.0 excluded) \
    /// `1.0.0>-<2.0.0` (versions 1.0.0 and 2.0.0 are excluded)
    case between((Version, Bool), and: (Version, Bool))
    
    func contains(_ other: Version) -> Bool {
        switch self {
        case let .equal(version):
            other == version
        case let .lesserThan(version):
            if version.1 {
                other <= version.0
            } else {
                other < version.0
            }
        case let .greaterThan(version):
            if version.1 {
                other >= version.0
            } else {
                other > version.0
            }
        case let .between(lower, upper):
            switch (lower.1, upper.1) {
            case (false, false):
                other > lower.0 && other < upper.0
            case (false, true):
                other > lower.0 && other <= upper.0
            case (true, false):
                other >= lower.0 && other < upper.0
            case (true, true):
                other >= lower.0 && other <= upper.0
            }
        }
    }
    
    var rawValue: String {
        switch self {
        case let .equal(version):
            version.rawValue
        case let .lesserThan(version):
            if version.1 {
                "<=\(version.0.rawValue)"
            } else {
                "<\(version.0.rawValue)"
            }
        case let .greaterThan(version):
            if version.1 {
                ">=\(version.0.rawValue)"
            } else {
                ">\(version.0.rawValue)"
            }
        case let .between(lower, upper):
            switch (lower.1, upper.1) {
            case (false, false):
                "\(lower.0.rawValue)>-<\(upper.0.rawValue)"
            case (false, true):
                "\(lower.0.rawValue)>-\(upper.0.rawValue)"
            case (true, false):
                "\(lower.0.rawValue)-<\(upper.0.rawValue)"
            case (true, true):
                "\(lower.0.rawValue)-\(upper.0.rawValue)"
            }
        }
    }
    
    public init(_ rawValue: String) throws {
        let parts = rawValue
            .split(separator: "-")
            .map { String($0) }
        if parts.count == 2 {
            let lower = parts[0]
            let lowerIncluded = !lower.hasSuffix(">")
            let lowerVersion = try Version(String(lower.dropLast(lowerIncluded ? 0 : 1)))
            let upper = parts[1]
            let upperIncluded = !upper.hasPrefix("<")
            let upperVersion = try Version(String(upper.dropFirst(upperIncluded ? 0 : 1)))
            self = .between((lowerVersion, lowerIncluded), and: (upperVersion, upperIncluded))
        } else if parts.count == 1 {
            let part = parts[0]
            if part.hasPrefix("<=") || part.hasPrefix("=<"){
                let version = try Version(String(part.dropFirst(2)))
                self = .lesserThan((version, true))
            } else if part.hasPrefix("<") {
                let version = try Version(String(part.dropFirst(1)))
                self = .lesserThan((version, false))
            } else if part.hasPrefix(">=") || part.hasPrefix("=>") {
                let version = try Version(String(part.dropFirst(2)))
                self = .greaterThan((version, true))
            } else if part.hasPrefix(">") {
                let version = try Version(String(part.dropFirst(1)))
                self = .greaterThan((version, false))
            } else if part.hasPrefix("=") {
                let version = try Version(String(part.dropFirst(1)))
                self = .equal(version)
            } else {
                let version = try Version(String(part))
                self = .equal(version)
            }
        } else {
            throw ConfigError.invalidVersionRange
        }
    }
}
