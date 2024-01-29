import AppRemoteConfig
import ArgumentParser
import Foundation
import Yams

extension Care {
    struct Resolve: ParsableCommand {
        static var configuration =
            CommandConfiguration(abstract: "Resolve a configuration for an app to verify output.")

        @Argument(
            help: "The file that contains the configuration.",
            completion: .file(extensions: ["yaml", "yml", "json"]), transform: URL.init(fileURLWithPath:))
        var inputFile: URL
        
        @Option(
            name: [.long, .customShort("v")],
            help: "The version of the app.",
            completion: .none)
        var appVersion: String = "1.0.0"
        
        @Option(
            name: [.customShort("d"), .long],
            help: "The date the app runs at in ISO8601 format. (default: now)"
        )
        var date: String?
        
        @Option(
            name: [.customShort("p"), .long],
            help: "The platform the app runs on."
        )
        var platform: Platform =  .iOS
        
        @Option(
            help: "The version of the platform the app runs on.",
            completion: .none)
        var platformVersion: String = "1.0.0"
        
        @Option(help: "The variant of the app.")
        var variant: String?
        
        @Option(help: "The build variant of the app.")
        var buildVariant: BuildVariant = .release
        
        @Option(help: "The 2 character code of the language the app runs in.")
        var language: String?
        
        mutating func run() throws {
            let data = try Data(contentsOf: inputFile)
            var object: [String: Any]
            
            if let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []) {
                if let jsonDict = jsonObject as? [String: Any] {
                    object = jsonDict
                } else {
                    throw CareError.unexpectedData
                }
            } else {
                let string = String(data: data, encoding: .utf8)!
                if let yamlObject = try? Yams.load(yaml: string) {
                    if let yamlDict = yamlObject as? [String: Any] {
                        object = yamlDict
                    } else {
                        throw CareError.unexpectedData
                    }
                } else {
                    throw CareError.unexpectedData
                }
            }
            let config = try Config(json: object)
            let parsedDate: Date
            if let date {
                guard let date = ISO8601DateFormatter().date(from: date) else {
                    throw CareError.invalidDate
                }
                parsedDate = date
            } else {
                parsedDate = Date()
            }
            let platformVersion = try Version(platformVersion).operatingSystemVersion
            let appVersion = try Version(appVersion)
            
            var relevantResolutionDates = config.relevantResolutionDates(
                platform: platform,
                platformVersion: platformVersion,
                appVersion: appVersion,
                variant: variant,
                buildVariant: buildVariant,
                language: language
            )
                .filter { $0.timeIntervalSince(parsedDate) > 0 }
            relevantResolutionDates.insert(parsedDate, at: 0)
            
            print("Resolving for:")
            print("  platform            : \(platform.rawValue)")
            print("  platform version    : \(platformVersion.majorVersion).\(platformVersion.minorVersion).\(platformVersion.patchVersion)")
            print("  app version         : \(appVersion.rawValue)")
            if let variant {
                print("  variant             : \(variant)")
            }
            print("  build variant       : \(buildVariant)")
            if let language {
                print("  language            : \(language)")
            }
            
            let defaultSettings = config.settings
            
            for relevantResolutionDate in relevantResolutionDates {
                let resolvedSettings = config.resolve(
                    date: relevantResolutionDate,
                    platform: platform,
                    platformVersion: platformVersion,
                    appVersion: appVersion,
                    variant: variant,
                    buildVariant: buildVariant,
                    language: language
                )
                print("")
                print("Settings on \(relevantResolutionDate):")
                for key in resolvedSettings.keys.sorted() {
                    let paddedKey = key + Array(repeating: " ", count: max(20 - key.count, 0))
                    if defaultSettings.keys.contains(key) {
                        let defaultValue = "\(defaultSettings[key]!)"
                        let resolvedValue = "\(resolvedSettings[key]!)"
                        if defaultValue == resolvedValue {
                            print("  \(paddedKey): \(resolvedValue)")
                        } else {
                            print("  \(paddedKey): \(defaultValue, effect: .faint) -> \(resolvedValue)")
                        }
                    } else {
                        print("  \(paddedKey): \("[deprecated]", effect: .faint) -> \(resolvedSettings[key]!)")
                    }
                }
            }
            print("")
            print("No further overrides scheduled.")
        }
    }
}

extension BuildVariant: ExpressibleByArgument { }
extension Platform: ExpressibleByArgument { }
