@testable import AppRemoteConfigService
import Dependencies
import Foundation
import XCTest

final class AppRemoteConfigTests: XCTestCase {
    
    @MainActor
    class Values {
        init() {
            foo = nil
        }
        
        var foo: Bool?
        
        func apply(settings: [String: Any]) throws {
            foo = settings["foo"] as? Bool
        }
    }
    
    @MainActor
    func testSomething() async throws {
        let values = Values()
        let sut = withDependencies {
            $0.date.now = Date(timeIntervalSince1970: 0)
        } operation: {
            AppRemoteConfigService(
                url: URL(string: "http://www.example.com")!,
                publicKey: nil,
                minimumRefreshInterval: 60,
                automaticRefreshInterval: 120,
                bundledConfigURL: nil,
                bundleIdentifier: "com.egeniq.projects.appremoteconfigservice.test",
                apply: values.apply(settings:)
            )
        }
        
        let settings = sut.resolve(date: Date(timeIntervalSince1970: 0))
        XCTAssertEqual(settings.keys.count, 0)
        
        // TODO: More extensive tests
        // Mocking content of config not very feasible this way
    }
}
