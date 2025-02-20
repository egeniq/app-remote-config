import AppRemoteConfig
import ArgumentParser
import Crypto
import Foundation
import Yams

extension Care {
    struct Prepare: ParsableCommand {
        static let configuration =
            CommandConfiguration(abstract: "Prepare a configuration for publication.")

        @Option(
            help: "The base64 encoded private key to use for signing the configuration.")
        var `private`: String?
        
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
            var object: [String: Sendable]
            
            if let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []) {
                if let jsonDict = jsonObject as? [String: Sendable] {
                    object = jsonDict
                } else {
                    throw CareError.unexpectedData
                }
            } else {
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
            }
           
            let dataOut = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
            
            var results = [VerificationResult]()
            if let `private` {
                guard let privateKeyData = Data(base64Encoded: `private`) else {
                    throw CareError.invalidPrivateKey
                }
                let privateKey = try Curve25519.Signing.PrivateKey(rawRepresentation: privateKeyData)
                let encodedDataOut = dataOut.base64EncodedString()
                let signature = try privateKey.signature(for: dataOut)
                let signedDataOut = try JSONSerialization.data(
                    withJSONObject: [
                        Config.dataKey: encodedDataOut,
                        Config.signatureKey: signature.base64EncodedString()
                    ],
                    options: [.sortedKeys]
                )
                try signedDataOut.write(to: outputFile)
            } else {
                results.append(.init(level: .info, message: "The configuration is not signed.", keyPath: ""))
                try dataOut.write(to: outputFile)
            }
            print("This configuration is \("prepared", effect: .green).")
            results.forEach {
                print("\($0.level.text) \($0.message) - \($0.keyPath, effect: .faint)")
            }
        }
    }
}
