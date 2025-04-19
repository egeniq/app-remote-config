import AppRemoteConfig
import ArgumentParser
import Crypto
import Foundation
import Yams

extension Care {
    struct Generate: ParsableCommand {
        static let configuration =
            CommandConfiguration(abstract: "Generate Swift code for your app.")

        @Argument(
            help: "The file that contains the configuration.",
            completion: .file(extensions: ["yaml", "yml", "json"]), transform: URL.init(fileURLWithPath:))
        var inputFile: URL
        
//        @Argument(
//            help: "The file that will contain the swift code.",
//            completion: .file(extensions: ["swift"]), transform: URL.init(fileURLWithPath:))
//        var outputFile: URL

        
        @Option(
            help:
                "Output directory where the generated files are written. Warning: Replaces any existing files with the same filename. Reserved filenames: \(GeneratorMode.allOutputFileNames.joined(separator: ", "))"
        ) var outputDirectory: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        
        @Option(
             help:
                 "Source of invocation if by a plugin. The generator needs to produce all files when invoked as a build plugin, so non-requested modes produce empty files."
         ) var pluginSource: PluginSource?
        
        @Option(
            help: "The file that contains the settings.",
            completion: .file(extensions: ["yaml", "yml"]), transform: URL.init(fileURLWithPath:))
        var settings: URL
        
        mutating func run() throws {
            let data = try Data(contentsOf: inputFile)
            let config: Config
           
            if let _ = try? JSONSerialization.jsonObject(with: data, options: []) {
//                if let `public` {
//                    guard let publicKeyData = Data(base64Encoded: `public`) else {
//                        throw CareError.invalidPublicKey
//                    }
//                    let key = try Curve25519.Signing.PublicKey(rawRepresentation: publicKeyData)
//                    config = try Config(data: data, publicKey: key)
//                } else {
                    config = try Config(data: data)
//                }
            } else {
//                if `public` != nil {
//                    print("\("[WARNING]", effect: .yellow) Config is not signed, but a public key was provided.")
//                }
                var object: [String: Sendable]
                let string = String(data: data, encoding: .utf8)!
                if let yamlObject = try? Yams.load(yaml: string) {
                    if let yamlDict = yamlObject as? [String: Sendable] {
                        object = yamlDict
                    } else {
                        throw CareError.unexpectedData
                    }
                } else {
                    throw CareError.unexpectedData
                }
                config = try Config(json: object)
            }
            
            let s = config.settings
            
            var sout: String = """
            import Sharing
            
            
            """
            
            for (key, value) in s {
                let valueType: String
                let valueValue: String
                if let value = value as? Bool {
                    valueType = "Bool"
                    valueValue = value ? "true" : "false"
                } else if let value = value as? Int {
                    valueType = "Int"
                    valueValue = "\(value)"
                } else if let value = value as? String {
                    valueType = "String"
                    valueValue = value
                } else {
                    fatalError()
                }
                sout += """
                public extension SharedKey where Self == InMemoryKey<\(valueType)>.Default {
                    static var \(key): Self {
                        Self[.inMemory("\(key)"), default: \(valueValue)]
                    }
                }
                
                
                """
            }
            
            if #available(macOS 13.0, *) {
                try sout.data(using: .utf8)!.write(to: outputDirectory.appending(path: "Sharing.swift"))
            } else {
                // Fallback on earlier versions
            }
        }
        
        
    }
}

extension PluginSource: ExpressibleByArgument {}

extension URL: @retroactive ExpressibleByArgument {}

extension URL {

    /// Creates a `URL` instance from a string argument.
    ///
    /// Initializes a `URL` instance using the path provided as an argument string.
    /// - Parameter argument: The string argument representing the path for the URL.
    public init?(argument: String) { self.init(fileURLWithPath: argument) }
}

