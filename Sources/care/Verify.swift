import AppRemoteConfig
import ArgumentParser
import Foundation
import Yams

extension Care {
    struct Verify: ParsableCommand {
        static var configuration =
            CommandConfiguration(abstract: "Verify that the configuration is valid.")

        @Argument(
            help: "The file that contains the configuration.",
            completion: .file(extensions: ["yaml", "yml", "json"]), transform: URL.init(fileURLWithPath:))
        var inputFile: URL
        
        mutating func run() throws {
            let data = try Data(contentsOf: inputFile)
            let results = try verify(from: data)
            if results.filter({ $0.level == .error }).isEmpty {
                print("This configuration is \("valid", effect: .green).")
                results.forEach {
                    print("\($0.level.text) \($0.message) - \($0.keyPath, effect: .faint)")
                }
                print("\("[HINT]", effect: .cyan) Use the resolve command to verify the output is as expected for an app.")
                print("\("[HINT]", effect: .cyan) Use the prepare command to prepare the configuration for publication.")

            } else {
                print("This configuration has \(results.count, effect: .bold) issue(s).")
                results.forEach {
                    print("\($0.level.text) \($0.message) - \($0.keyPath, effect: .faint)")
                }
            }
        }
        
        func verify(from data: Data) throws -> [VerificationResult]  {
            var results = [VerificationResult]()
            
            var object: [String: Any]
            
            if let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []) {
                if let jsonDict = jsonObject as? [String: Any] {
                    object = jsonDict
                } else {
                    results.append(.init(level: .error, message: "Expected a dictionary with string keys.", keyPath: "/"))
                    return results
                }
            } else {
                let string = String(data: data, encoding: .utf8)!
                if let yamlObject = try? Yams.load(yaml: string) {
                    if let yamlDict = yamlObject as? [String: Any] {
                        object = yamlDict
                        results.append(.init(level: .info, message: "This configuration is in YAML. This is not suitable for publication. Use the prepare command to convert to JSON.", keyPath: "/"))
                    } else {
                        results.append(.init(level: .error, message: "Expected a dictionary with string keys.", keyPath: "/"))
                        return results
                    }
                } else {
                    results.append(.init(level: .error, message: "Expected YAML or JSON file.", keyPath: ""))
                    return results
                }
            }
            
            var configKeys: [String] = []
            if let settings = object["settings"] {
                let keyPath = "/settings"
                if let settings = settings as? [String: Any]  {
                    // No further checks (yet)
                    configKeys = Array(settings.keys)
                } else {
                    results.append(.init(level: .error, message: "Expected a dictionary with string keys.", keyPath: keyPath))
                }
            } else {
                results.append(.init(level: .error, message: "Missing settings.", keyPath: "/"))
            }
            
            var deprecatedKeys2: [String] = []
            if let deprecatedKeys = object["deprecatedKeys"] {
                let keyPath = "/deprecatedKeys"
                if let deprecatedKeys = deprecatedKeys as? [String] {
                    deprecatedKeys2 = deprecatedKeys
                    // no duplicates in keys??
                    if let duplicateKey = deprecatedKeys.first(where: { configKeys.contains($0) } ) {
                        results.append(.init(level: .error, message: "Deprecated key '\(duplicateKey)' is still used.", keyPath: keyPath))
                    }
                    
                    let duplicateKeys = Dictionary(grouping: deprecatedKeys, by: { $0 }).filter { $1.count > 1 }.keys
                    for duplicateKey in duplicateKeys {
                        results.append(.init(level: .warning, message: "Deprecated key '\(duplicateKey)' is listed more than once.", keyPath: keyPath))
                    }
                } else {
                    results.append(.init(level: .error, message: "Expected an array of strings.", keyPath: keyPath))
                }
            }
            
            if let overrides = object["overrides"] {
                let keyPath = "/overrides"
                if let overrides = overrides as? [[String: Any]]  {
                    for (index, override) in overrides.enumerated() {
                        let keyPath = "/overrides[\(index)]"
                        
                        var hasConditions = false
                        if let conditions = override["matching"] {
                            let keyPath = "\(keyPath)/matching"
                            if let conditions = conditions as? [[String: Any]]  {
                                for (index, condition) in conditions.enumerated() {
                                    hasConditions = true
                                    
                                    let keyPath = "\(keyPath)[\(index)]"
                                    let conditionKeys: [String] = Array(condition.keys)
                                    
                                    // matching should have no unknown keys
                                    let unknownKeys = conditionKeys.filter({ !["platform", "platformVersion", "appVersion", "variant", "buildVariant", "language"].contains($0) })
                                    for unknownKey in unknownKeys {
                                        results.append(.init(level: .error, message: "Unexpected key '\(unknownKey)' in condition.", keyPath: keyPath))
                                    }
                                    
                                    // matching should have at least one key
                                    if conditionKeys.isEmpty {
                                        results.append(.init(level: .error, message: "No keys in condition.", keyPath: keyPath))
                                    }
                                    
                                    // platform should not be unknown/other
                                    if let platform = condition["platform"] {
                                        let keyPath = "\(keyPath)/platform"
                                        if let platform = platform as? String {
                                            let parsedPlatform = Platform(rawValue: platform)
                                            if parsedPlatform == nil || parsedPlatform == .unknown {
                                                results.append(.init(level: .error, message: "Unknown platform '\(platform)'.", keyPath: keyPath))
                                            }
                                        } else {
                                            results.append(.init(level: .error, message: "Expected a string.", keyPath: keyPath))
                                        }
                                    }
                                    
                                    // versions range is valid
                                    if let platformVersion = condition["platformVersion"] {
                                        let keyPath = "\(keyPath)/platformVersion"
                                        if let platformVersion = platformVersion as? String {
                                            let parsedVersionRange = try? VersionRange(platformVersion)
                                            if parsedVersionRange == nil {
                                                results.append(.init(level: .error, message: "Invalid platform version range '\(platformVersion)'.", keyPath: keyPath))
                                            }
                                            let invalidCharacters = CharacterSet(charactersIn: "1234567890-<>=.").inverted
                                            if platformVersion.rangeOfCharacter(from: invalidCharacters) != nil {
                                                results.append(.init(level: .error, message: "Invalid platform version range '\(platformVersion)'.", keyPath: keyPath))
                                            }
                                        } else {
                                            results.append(.init(level: .error, message: "Expected a string.", keyPath: keyPath))
                                        }
                                    }
                                    
                                    // versions range is valid
                                    if let appVersion = condition["appVersion"] {
                                        let keyPath = "\(keyPath)/appVersion"
                                        if let appVersion = appVersion as? String {
                                            let parsedVersionRange = try? VersionRange(appVersion)
                                            if parsedVersionRange == nil {
                                                results.append(.init(level: .error, message: "Invalid app version range '\(appVersion)'.", keyPath: keyPath))
                                            }
                                            let invalidCharacters = CharacterSet(charactersIn: "1234567890-<>=.").inverted
                                            if appVersion.rangeOfCharacter(from: invalidCharacters) != nil {
                                                results.append(.init(level: .error, message: "Invalid app version range '\(appVersion)'.", keyPath: keyPath))
                                            }
                                        } else {
                                            results.append(.init(level: .error, message: "Expected a string.", keyPath: keyPath))
                                        }
                                    }
                                    
                                    // variant should be string
                                    if let variant = condition["variant"] {
                                        let keyPath = "\(keyPath)/variant"
                                        if let _ = variant as? String {
                                            // No further checks (yet)
                                        } else {
                                            results.append(.init(level: .error, message: "Expected a string.", keyPath: keyPath))
                                        }
                                    }
                                    
                                    // buildVariant should not be unknown
                                    if let buildVariant = condition["buildVariant"] {
                                        let keyPath = "\(keyPath)/buildVariant"
                                        if let buildVariant = buildVariant as? String {
                                            let parsedBuildVariant = BuildVariant(rawValue: buildVariant)
                                            if parsedBuildVariant == nil || parsedBuildVariant == .unknown {
                                                results.append(.init(level: .error, message: "Unknown buildVariant '\(buildVariant)'.", keyPath: keyPath))
                                            }
                                        } else {
                                            results.append(.init(level: .error, message: "Expected a string.", keyPath: keyPath))
                                        }
                                    }
                                    
                                    // language should be lower cased and two letters
                                    if let language = condition["language"] {
                                        let keyPath = "\(keyPath)/language"
                                        if let language = language as? String {
                                            if language.count != 2 || language.trimmingCharacters(in: CharacterSet.lowercaseLetters.inverted).count != 2 {
                                                results.append(.init(level: .error, message: "Invalid language code '\(language)'. Must be 2 lowercase characters.", keyPath: keyPath))
                                            }
                                        } else {
                                            results.append(.init(level: .error, message: "Expected a string.", keyPath: keyPath))
                                        }
                                    }
                                }
                            } else {
                                results.append(.init(level: .error, message: "Expected an array of dictionaries with string keys.", keyPath: keyPath))
                            }
                        }
                        // Check for
                                                
                        var hasSchedule = false
                        if let schedule = override["schedule"] {
                            let keyPath = "\(keyPath)/schedule"
                            if let schedule = schedule as? [String: String]  {
                                hasSchedule = true
                                // schedule should have from and/or until
                                let fromDate: Date?
                                if let from = schedule["from"] {
                                    fromDate = ISO8601DateFormatter().date(from: from)
                                    if fromDate == nil {
                                        results.append(.init(level: .error, message: "Invalid date '\(from)' is not ISO8601.", keyPath: keyPath + "/from"))
                                    }
                                } else {
                                    fromDate = nil
                                }
                                
                                let untilDate: Date?
                                if let until = schedule["until"] {
                                    untilDate = ISO8601DateFormatter().date(from: until)
                                    if untilDate == nil {
                                        results.append(.init(level: .error, message: "Invalid date '\(until)' is not ISO8601.", keyPath: keyPath + "/until"))
                                    }
                                } else {
                                    untilDate = nil
                                }
                                
                                if fromDate == nil && untilDate == nil {
                                    results.append(.init(level: .error, message: "Expected at least one of keys from and until.", keyPath: keyPath))
                                }
                       
                                // from until should be ordered
                                if let fromDate, let untilDate, fromDate >= untilDate {
                                    results.append(.init(level: .error, message: "Expected until date '\(untilDate)' to be later than from date '\(fromDate)'.", keyPath: keyPath))
                                }
                            } else {
                                results.append(.init(level: .error, message: "Expected a dictionary with string keys and values.", keyPath: keyPath))
                            }
                        }
                        
                        // must have matching and/or schedule key
                        if !hasConditions && !hasSchedule {
                            results.append(.init(level: .error, message: "Expected at least one of keys matching and schedule.", keyPath: keyPath))
                        }
                        
                        // using deprecated key must not match with current app version/code (warning?)
                        
                       
                        if let settings = override["settings"] {
                            let keyPath = "\(keyPath)/settings"
                            if let settings = settings as? [String: Any]  {
                                let overrideSettingsKeys = Array(settings.keys)
                                // settings should not be empty
                                if overrideSettingsKeys.isEmpty {
                                    results.append(.init(level: .error, message: "Expected a non-empty dictionary with string keys.", keyPath: keyPath))
                                }
                                for key in overrideSettingsKeys {
                                    // keys in settings must be used or deprecated
                                    if !configKeys.contains(key) && !deprecatedKeys2.contains(key) {
                                        results.append(.init(level: .error, message: "Key '\(key)' is not used in settings or listed in deprecated keys.", keyPath: keyPath))
                                    }
                                }
                            } else {
                                results.append(.init(level: .error, message: "Expected a dictionary with string keys.", keyPath: keyPath))
                            }
                        } else {
                            results.append(.init(level: .error, message: "Missing settings.", keyPath: "\(keyPath)/settings"))
                        }
                    }
                } else {
                    results.append(.init(level: .error, message: "Expected an array of dictionaries with string keys.", keyPath: keyPath))
                }
            }
            
            if let meta = object["meta"] {
                let keyPath = "/meta"
                if let _ = meta as? [String: Any]  {
                    // No further checks (yet)
                } else {
                    results.append(.init(level: .error, message: "Expected a dictionary with string keys.", keyPath: keyPath))
                }
            }
            
            return results
        }
    }
}

struct VerificationResult {
    enum Level {
        case info
        case warning
        case error
    }
    let level: Level
    let message: String
    let keyPath: String
}

extension VerificationResult.Level {
    var text: String {
        switch self {
        case .info:
            "\("[INFO]", effect: .green)"
        case .warning:
            "\("[WARNING]", effect: .yellow)"
        case .error:
            "\("[ERROR]", effect: .red)"
        }
    }
}

