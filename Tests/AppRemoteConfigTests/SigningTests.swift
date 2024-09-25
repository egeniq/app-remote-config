@testable import AppRemoteConfig
import Dependencies
import Foundation
import SodiumClientLive
import XCTest

@available(macOS 13, *) @MainActor
final class SigningTests: XCTestCase {
    
    // $> care create-key-pair
    // The public key is rK21qYyxsj8x75kCqU8k99zU4bEJdI60fMTPzsviBtE=.
    // The secret key is 7/z5fFbEF1xPlCWJdqhfd6SV5lp/xusUsc7VpYTAX2asrbWpjLGyPzHvmQKpTyT33NThsQl0jrR8xM/Oy+IG0Q==.
    
    func testVerifying() async throws {
        try withDependencies {
            $0.sodiumClient = .liveValue
        } operation: {
            let publicKey = "rK21qYyxsj8x75kCqU8k99zU4bEJdI60fMTPzsviBtE="
            let secretKey = "7/z5fFbEF1xPlCWJdqhfd6SV5lp/xusUsc7VpYTAX2asrbWpjLGyPzHvmQKpTyT33NThsQl0jrR8xM/Oy+IG0Q=="
            let configData = """
                {"settings": {"testing": true}}
                """.data(using: .utf8)!
            
            @Dependency(\.sodiumClient) var sodiumClient
            
            let signedData = sodiumClient.sign(message: configData, secretKey: secretKey)!
            let signedConfig = try Config(data: signedData, publicKey: publicKey)
            
            XCTAssertTrue(signedConfig.settings["testing"]! as! Bool)
        }
    }

    func testVerifyingWithIncorrectPublicKey() async throws {
        try withDependencies {
            $0.sodiumClient = .liveValue
        } operation: {
            let publicKey = "incorrectkey/5kCqU8k99zU4bEJdI60fMTPzsviBtE="
            let secretKey = "7/z5fFbEF1xPlCWJdqhfd6SV5lp/xusUsc7VpYTAX2asrbWpjLGyPzHvmQKpTyT33NThsQl0jrR8xM/Oy+IG0Q=="
            let configData = """
                {"settings": {"testing": true}}
                """.data(using: .utf8)!
            
            @Dependency(\.sodiumClient) var sodiumClient
            
            let signedData = sodiumClient.sign(message: configData, secretKey: secretKey)!
            
            XCTAssertThrowsError(try Config(data: signedData, publicKey: publicKey)) { error in
                XCTAssertEqual(error as! ConfigError, ConfigError.invalidSignature)
            }
        }
    }
    
    func testVerifyingWithInvalidSignature() async throws {
        try withDependencies {
            $0.sodiumClient = .liveValue
        } operation: {
            let publicKey = "rK21qYyxsj8x75kCqU8k99zU4bEJdI60fMTPzsviBtE="
            let secretKey = "7/z5fFbEF1xPlCWJdqhfd6SV5lp/xusUsc7VpYTAX2asrbWpjLGyPzHvmQKpTyT33NThsQl0jrR8xM/Oy+IG0Q=="
            let configData = """
                {"settings": {"testing": true}}
                """.data(using: .utf8)!
            
            @Dependency(\.sodiumClient) var sodiumClient
            
            var signedData = sodiumClient.sign(message: configData, secretKey: secretKey)!
            // Invalidate signature
            signedData.replaceSubrange(0..<1, with: "1".data(using: .utf8)!)
            XCTAssertThrowsError(try Config(data: signedData, publicKey: publicKey)) { error in
                XCTAssertEqual(error as! ConfigError, ConfigError.invalidSignature)
            }
        }
    }
}
