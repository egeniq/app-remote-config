import Crypto
import Foundation

extension Config {
    
    /// Key under which the signed base64 encoded data is stored
    public static let dataKey: String = "d"
    
    /// Key under which the  base64 encoded signature is stored
    public static let signatureKey: String = "sig"
    
    /// Create a config from signed JSON
    /// - Parameters:
    ///   - data: Data containing signed JSON describing the desired configuration according to this [scheme](https://raw.githubusercontent.com/egeniq/app-remote-config/main/Schema/appremoteconfig.schema.json)
    ///   - publicKey: Curve25519 public key that was used to sign the data.
    public init(data: Data, publicKey: Curve25519.Signing.PublicKey) throws {
        guard let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
            throw ConfigError.unexpectedTypeForKey("root")
        }
        guard 
            let encodedConfigData: String = json[Self.dataKey] as? String,
            let configData = Data(base64Encoded: encodedConfigData),
            let encodedSignature = json[Self.signatureKey] as? String,
            let signature = Data(base64Encoded: encodedSignature) else {
            throw ConfigError.base64DecodingFailed
        }
       
        guard publicKey.isValidSignature(signature, for: configData) else {
            throw ConfigError.invalidSignature
        }

        try self.init(data: configData)
    }
}

