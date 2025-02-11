import Crypto
import Foundation

extension Config {
   
    /// Create a config from signed JSON
    /// - Parameters:
    ///   - data: Data containing signed JSON describing the desired configuration according to this [scheme](https://raw.githubusercontent.com/egeniq/app-remote-config/main/Schema/appremoteconfig.schema.json)
    ///   - publicKey: Curve25519 public key that was used to sign the data.
    public init(data: Data, publicKey: Curve25519.Signing.PublicKey) throws {
        guard let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
            throw ConfigError.unexpectedTypeForKey("root")
        }
        guard 
            let encodedConfigData: String = json["data"] as? String, 
            let configData = Data(base64Encoded: encodedConfigData), 
            let encodedSignature = json["signature"] as? String,
            let signature = Data(base64Encoded: encodedSignature) else {
            throw ConfigError.base64DecodingFailed
        }
       
        guard publicKey.isValidSignature(signature, for: configData) else {
            throw ConfigError.invalidSignature
        }

        try self.init(data: configData)
    }

    /// Signs the configuration data using the provided private key.
    /// 
    /// This method serializes the configuration data into JSON format, signs it using the provided Curve25519 private key, 
    /// and then returns the signed data along with the signature in a JSON format.
    ///
    /// - Parameter privateKey: The Curve25519 private key used to sign the data.
    /// - Throws: An error if the data serialization or signing process fails.
    /// - Returns: A `Data` object containing the signed configuration data and the signature in JSON format.
    public func signedData(privateKey: Curve25519.Signing.PrivateKey) throws -> Data {
        let data = try JSONSerialization.data(withJSONObject: [
            "settings": settings,
            "deprecatedKeys": deprecatedKeys,
            "overrides": overrides,
            "meta": meta
        ])
        
        let signature = try privateKey.signature(for: data)

        return try JSONSerialization.data(withJSONObject: [
            "data": data.base64EncodedString(),
            "signature": signature.base64EncodedString() 
        ])
    }
}

