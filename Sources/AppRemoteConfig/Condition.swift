import Foundation

public enum BuildVariant: String, CaseIterable {
    case release
    case debug
    case unknown
}

struct Condition {
    let matchNever: Bool
    let platform: Platform?
    let platformVersion: VersionRange?
    let appVersion: VersionRange?
    let variant: String?
    let buildVariant: BuildVariant?
    let language: String?
    
    init(json: [String: Any]) {
        // If there is a new unknown key, never match condition
        guard !json.keys.contains(where: { !["platform", "platformVersion", "appVersion", "variant", "buildVariant", "language"].contains($0) }) else {
            matchNever = true
            platform = nil
            platformVersion = nil
            appVersion = nil
            variant = nil
            buildVariant = nil
            language = nil
            return
        }
        
        if let jsonValue = json["platform"] {
            if let string = jsonValue as? String {
                platform = Platform(rawValue: string) ?? .unknown
            } else {
                matchNever = true
                platform = nil
                platformVersion = nil
                appVersion = nil
                variant = nil
                buildVariant = nil
                language = nil
                return
            }
        } else {
            platform = nil
        }
        
        if let jsonValue = json["platformVersion"] {
            if let string = jsonValue as? String, let platformVersion = try? VersionRange(string) {
                self.platformVersion = platformVersion
            } else {
                matchNever = true
                platformVersion = nil
                appVersion = nil
                variant = nil
                buildVariant = nil
                language = nil
                return
            }
        } else {
            platformVersion = nil
        }
        
        if let jsonValue = json["appVersion"] {
            if let string = jsonValue as? String, let appVersion = try? VersionRange(string) {
                self.appVersion = appVersion
            } else {
                matchNever = true
                appVersion = nil
                variant = nil
                buildVariant = nil
                language = nil
                return
            }
        } else {
            appVersion = nil
        }
        
        if let jsonValue = json["variant"] {
            if let string = jsonValue as? String {
                variant = string
            } else {
                matchNever = true
                variant = nil
                buildVariant = nil
                language = nil
                return
            }
        } else {
            variant = nil
        }
        
        if let jsonValue = json["buildVariant"] {
            if let string = jsonValue as? String {
                buildVariant = BuildVariant(rawValue: string) ?? .unknown
            } else {
                matchNever = true
                buildVariant = nil
                language = nil
                return
            }
        } else {
            buildVariant = nil
        }
        
        if let jsonValue = json["language"] {
            if let string = jsonValue as? String {
                language = string
            } else {
                matchNever = true
                language = nil
                return
            }
        } else {
            language = nil
        }
        
        matchNever = false
    }
    
    func matches(platform: Platform, platformVersion: OperatingSystemVersion, appVersion: Version, variant: String? = nil, buildVariant: BuildVariant, language: String?) -> Bool {
        if matchNever {
            return false
        }
        
        if let platformToMatch = self.platform, !platformToMatch.applies(to: platform) {
            return false
        }
        
        if let platformVersionToMatch = self.platformVersion, !platformVersionToMatch.contains(Version(platformVersion)) {
            return false
        }
        
        if let appVersionToMatch = self.appVersion, !appVersionToMatch.contains(appVersion) {
            return false
        }
        
        if let variant, let variantToMatch = self.variant, !variantToMatch.contains(variant) {
            return false
        }
        
        if let buildVariantToMatch = self.buildVariant, buildVariantToMatch != buildVariant {
            return false
        }
        
        if let language, let languageToMatch = self.language, !language.hasPrefix(languageToMatch) {
            return false
        }
        
        return true
    }
}
