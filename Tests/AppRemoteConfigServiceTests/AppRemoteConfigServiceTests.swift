@testable import AppRemoteConfigService
import CombineSchedulers
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
            $0.mainQueue = DispatchQueue.test.eraseToAnyScheduler()
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
    }

    @MainActor
    private func makeService(
        variant: String?,
        json: String = """
        {
            "settings": { "foo": true },
            "overrides": [
                { "matching": [{ "variant": "AppStore" }], "settings": { "foo": false } }
            ]
        }
        """,
        apply: @escaping @Sendable @MainActor ([String: any Sendable]) throws -> () = { _ in }
    ) throws -> AppRemoteConfigService {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).json")
        try json.write(to: url, atomically: true, encoding: .utf8)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return withDependencies {
            $0.date.now = Date(timeIntervalSince1970: 0)
            $0.mainQueue = DispatchQueue.test.eraseToAnyScheduler()
        } operation: {
            AppRemoteConfigService(
                url: URL(string: "http://www.example.com")!,
                publicKey: nil,
                bundledConfigURL: url,
                variant: variant,
                bundleIdentifier: "com.egeniq.projects.appremoteconfigservice.test.\(UUID().uuidString)",
                apply: apply
            )
        }
    }
    
    @MainActor
    func testResolveUsesServiceVariant() throws {
        let date = Date(timeIntervalSince1970: 0)
        XCTAssertEqual(try makeService(variant: "AppStore").resolve(date: date)["foo"] as? Bool, false)
        XCTAssertEqual(try makeService(variant: "TestFlight").resolve(date: date)["foo"] as? Bool, true)
        XCTAssertEqual(try makeService(variant: nil).resolve(date: date)["foo"] as? Bool, true)
    }
    
    @MainActor
    func testChangingVariantReResolvesAndApplies() async throws {
        let box = LockedBox()
        let sut = try makeService(variant: nil) { settings in
            box.set(settings["foo"] as? Bool)
        }
        let date = Date(timeIntervalSince1970: 0)
        XCTAssertEqual(sut.resolve(date: date)["foo"] as? Bool, true)
        sut.variant = "AppStore"
        XCTAssertEqual(sut.resolve(date: date)["foo"] as? Bool, false)
        XCTAssertEqual(box.value, false)
    }
    
    @MainActor
    func testResolveReflectsVariantChanges() throws {
        let sut = try makeService(variant: nil)
        let date = Date(timeIntervalSince1970: 0)
        sut.variant = "AppStore"
        XCTAssertEqual(sut.resolve(date: date)["foo"] as? Bool, false)
        sut.variant = "Other"
        XCTAssertEqual(sut.resolve(date: date)["foo"] as? Bool, true)
    }
    
    private let scheduledJSON = """
    {
        "settings": { "foo": 1 },
        "overrides": [
            {
                "schedule": { "from": "1970-01-01T01:00:00Z", "until": "1970-01-01T02:00:00Z" },
                "settings": { "foo": 2 }
            }
        ]
    }
    """
    
    @MainActor
    func testResolveReturnsBaseSettings() throws {
        let sut = try makeService(variant: nil, json: #"{ "settings": { "foo": 1, "bar": "x" } }"#)
        let settings = sut.resolve(date: Date(timeIntervalSince1970: 0))
        XCTAssertEqual(settings["foo"] as? Int, 1)
        XCTAssertEqual(settings["bar"] as? String, "x")
    }
    
    @MainActor
    func testResolveAppliesScheduledOverrideOnlyWithinSchedule() throws {
        let sut = try makeService(variant: nil, json: scheduledJSON)
        XCTAssertEqual(sut.resolve(date: Date(timeIntervalSince1970: 0))["foo"] as? Int, 1)
        XCTAssertEqual(sut.resolve(date: Date(timeIntervalSince1970: 5400))["foo"] as? Int, 2)
        XCTAssertEqual(sut.resolve(date: Date(timeIntervalSince1970: 10800))["foo"] as? Int, 1)
    }
    
    @MainActor
    func testNextResolutionDate() throws {
        let sut = try makeService(variant: nil, json: scheduledJSON)
        XCTAssertEqual(sut.nextResolutionDate(after: Date(timeIntervalSince1970: 0)), Date(timeIntervalSince1970: 3600))
        XCTAssertEqual(sut.nextResolutionDate(after: Date(timeIntervalSince1970: 3600)), Date(timeIntervalSince1970: 7200))
        XCTAssertNil(sut.nextResolutionDate(after: Date(timeIntervalSince1970: 7200)))
    }
    
    @MainActor
    func testNextResolutionDateIsNilWithoutSchedules() throws {
        let sut = try makeService(variant: nil)
        XCTAssertNil(sut.nextResolutionDate(after: Date(timeIntervalSince1970: 0)))
    }
    
    @MainActor
    func testBundledConfigIsAppliedOnInit() async throws {
        let applied = expectation(description: "settings applied")
        applied.assertForOverFulfill = false
        let box = LockedBox()
        _ = try makeService(variant: "AppStore") { settings in
            box.set(settings["foo"] as? Bool)
            applied.fulfill()
        }
        await fulfillment(of: [applied], timeout: 5)
        XCTAssertEqual(box.value, false)
    }
    
    @MainActor
    func testMissingConfigResolvesToEmptySettings() throws {
        let sut = try makeService(variant: nil, json: #"{ "settings": {} }"#)
        XCTAssertTrue(sut.resolve(date: Date(timeIntervalSince1970: 0)).isEmpty)
    }
}

final class LockedBox: @unchecked Sendable {
    private let lock = NSLock()
    private var _value: Bool?
    var value: Bool? { lock.withLock { _value } }
    func set(_ v: Bool?) { lock.withLock { _value = v } }
}
