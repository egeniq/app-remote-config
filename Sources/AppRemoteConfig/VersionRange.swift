import Foundation

public enum VersionRange {
    case equal(Version)
    case lesserThan((Version, Bool))
    case greaterThan((Version, Bool))
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
