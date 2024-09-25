import Dependencies
import Foundation
import Sodium
import SodiumClient

extension SodiumClient: DependencyKey {
    public static let liveValue = Self(
        keyPair: {
            guard let keyPair = Sodium().sign.keyPair() else {
                return nil
            }
            
            let publicKey = keyPair.publicKey.data.base64EncodedString()
            let secretKey = keyPair.secretKey.data.base64EncodedString()
            return (publicKey, secretKey)
        },
        open: { signedMessage, publicKey in
            guard let publicKey = Data(base64Encoded: publicKey)?.bytes else {
                return nil
            }
            return Sodium().sign.open(signedMessage: signedMessage.bytes, publicKey: publicKey)?.data
        },
        sign: { message, secretKey in
            guard let secretKey = Data(base64Encoded: secretKey)?.bytes else {
                return nil
            }
            return Sodium().sign.sign(message: message.bytes, secretKey: secretKey)?.data
        }
    )
}
