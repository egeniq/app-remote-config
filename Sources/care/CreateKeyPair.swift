import AppRemoteConfig
import ArgumentParser
import Crypto
import Foundation

extension Care {
    struct CreateKeyPair: ParsableCommand {
        static let configuration =
            CommandConfiguration(abstract: "Prepare a new key pair for signing a config.")
        
        mutating func run() throws {
            let privateKey = Curve25519.Signing.PrivateKey()
            
            let publicKeyString = privateKey.publicKey.rawRepresentation.base64EncodedString()
            print("The \("public", effect: .bold) key is \"\(publicKeyString, effect: .blue)\"")
            
            let privateKeyString = privateKey.rawRepresentation.base64EncodedString()
            print("The \("private", effect: .bold) key is \"\(privateKeyString, effect: .yellow)\"")
        }
    }
}
