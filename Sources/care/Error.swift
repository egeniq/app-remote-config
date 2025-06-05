import Foundation

enum CareError: Error {
    case fileAlreadyExists
    case unexpectedData
    case invalidDate
    case invalidPublicKey
    case invalidPrivateKey
    case invalidSignature
}
