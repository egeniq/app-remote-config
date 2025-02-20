import AppRemoteConfig
import ArgumentParser
import Foundation

extension Care {
    struct Init: ParsableCommand {
        static let configuration =
            CommandConfiguration(abstract: "Prepare a new configuration.")

        enum Kind: String, ExpressibleByArgument, CaseIterable {
            case yaml, json
        }

        @Option(help: "The kind of configuration file.")
        var kind: Kind = .yaml
        
        @Argument(
            help: "The file that will contain the configuration.",
            completion: .file(extensions: ["yaml", "yml", "json"]), transform: URL.init(fileURLWithPath:))
        var outputFile: URL
        
        mutating func run() throws {
            // Just writing text to disk, so we can add some helpful comments
            switch kind {
            case .yaml:
                let yaml = """
                # yaml-language-server: $schema=https://raw.githubusercontent.com/egeniq/app-remote-config/main/Schema/appremoteconfig.schema.json
                $schema: https://raw.githubusercontent.com/egeniq/app-remote-config/main/Schema/appremoteconfig.schema.json
                
                # Settings for the current app.
                settings:
                  foo: 42
                  coolFeature: false

                # Keep track of keys that are no longer in use.
                deprecatedKeys:
                - bar

                # Override settings
                overrides:
                - matching:
                  # If any of the following combinations match
                  - appVersion: <=0.9.0
                    platform: Android
                  - appVersion: <1.0.0
                    platform: iOS
                  - platformVersion: <15.0.0
                    platform: iOS.iPad
                  # These settings get overriden.
                  settings:
                    bar: low
                 
                # Or release a new feature at a specific time
                - schedule:
                    from: '2024-12-31T00:00:00Z'
                  settings:
                    coolFeature: true
                    
                # Store metadata here
                meta:
                  author: Your Name
                """
                try yaml.write(to: outputFile, atomically: true, encoding: .utf8)
            case .json:
                let json = """
                {
                    "$schema": "https://raw.githubusercontent.com/egeniq/app-remote-config/main/Schema/appremoteconfig.schema.json",
                    "settings": {
                        "coolFeature": false,
                        "foo": 42
                    },
                    "deprecatedKeys": [
                        "bar"
                    ],
                    "overrides": [
                        {
                            "matching": [
                                {
                                    "appVersion": "<=0.9.0",
                                    "platform": "Android"
                                },
                                {
                                    "appVersion": "<1.0.0",
                                    "platform": "iOS"
                                },
                                {
                                    "platform": "iOS.iPad",
                                    "platformVersion": "<15.0.0"
                                }
                            ],
                            "settings": {
                                "bar": "low"
                            }
                        },
                        {
                            "schedule": {
                                "from": "2024-12-31T00:00:00Z"
                            },
                            "settings": {
                                "coolFeature": true
                            }
                        }
                    ],
                    "meta": {
                        "author": "Your Name"
                    }
                }
                """
                try json.write(to: outputFile, atomically: true, encoding: .utf8)
            }
            let data = try Data(contentsOf: outputFile)
            let results = try Verify().verify(from: data).filter { $0.level != .info }
            if results.isEmpty {
                print("This configuration is \("created", effect: .green).")
                print("\("[HINT]", effect: .cyan) Use the resolve command to verify the output is as expected for an app.")
                print("\("[HINT]", effect: .cyan) Use the prepare command to prepare the configuration for publication.")
            } else {
                print("This configuration has \(results.count, effect: .bold) issue(s).")
                results.forEach {
                    print("\($0.level.text) \($0.message) - \($0.keyPath, effect: .faint)")
                }
            }
        }
    }
}
