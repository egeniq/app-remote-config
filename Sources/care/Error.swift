import Foundation

enum CareError: Error {
    case unexpectedData
    case invalidDate
    case invalidPublicKey
    case invalidPrivateKey
    case invalidSignature
}
