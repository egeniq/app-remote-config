import AppRemoteConfig
import ArgumentParser
import Foundation
import Yams

extension Care {
    struct Prepare: ParsableCommand {
        static var configuration =
            CommandConfiguration(abstract: "Prepare a configuration for publication.")

        @Argument(
            help: "The file that contains the configuration.",
            completion: .file(extensions: ["yaml", "yml", "json"]), transform: URL.init(fileURLWithPath:))
        var inputFile: URL
        
        @Argument(
            help: "The file that will contain the configuration suitable for publication.",
            completion: .file(extensions: ["json"]), transform: URL.init(fileURLWithPath:))
        var outputFile: URL
        
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
           
            let dataOut = try JSONSerialization.data(withJSONObject: object)
            let results = try Verify().verify(from: dataOut)
            if results.filter({ $0.level == .error }).isEmpty {
                try dataOut.write(to: outputFile)
                print("This configuration is \("prepared", effect: .green).")
                results.forEach {
                    print("\($0.level.text) \($0.message) - \($0.keyPath, effect: .faint)")
                }
            } else {
                print("This configuration has \(results.count, effect: .bold) issue(s).")
                results.forEach {
                    print("\($0.level.text) \($0.message) - \($0.keyPath, effect: .faint)")
                }
            }
           
        }
    }
}
