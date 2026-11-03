@testable import AppRemoteConfigService
import CombineSchedulers
import Dependencies
import Foundation
import Testing

@MainActor
struct AppRemoteConfigTests {
    
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
    
    @Test
    func something() async throws {
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
        #expect(settings.keys.count == 0)
    }

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
    
    @Test
    func resolveUsesServiceVariant() throws {
        let date = Date(timeIntervalSince1970: 0)
        #expect(try makeService(variant: "AppStore").resolve(date: date)["foo"] as? Bool == false)
        #expect(try makeService(variant: "TestFlight").resolve(date: date)["foo"] as? Bool == true)
        #expect(try makeService(variant: nil).resolve(date: date)["foo"] as? Bool == true)
    }
    
    @Test
    func changingVariantReResolvesAndApplies() async throws {
        let box = LockedBox()
        let sut = try makeService(variant: nil) { settings in
            box.set(settings["foo"] as? Bool)
        }
        let date = Date(timeIntervalSince1970: 0)
        #expect(sut.resolve(date: date)["foo"] as? Bool == true)
        sut.variant = "AppStore"
        #expect(sut.resolve(date: date)["foo"] as? Bool == false)
        #expect(box.value == false)
    }
    
    @Test
    func resolveReflectsVariantChanges() throws {
        let sut = try makeService(variant: nil)
        let date = Date(timeIntervalSince1970: 0)
        sut.variant = "AppStore"
        #expect(sut.resolve(date: date)["foo"] as? Bool == false)
        sut.variant = "Other"
        #expect(sut.resolve(date: date)["foo"] as? Bool == true)
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
    
    @Test
    func resolveReturnsBaseSettings() throws {
        let sut = try makeService(variant: nil, json: #"{ "settings": { "foo": 1, "bar": "x" } }"#)
        let settings = sut.resolve(date: Date(timeIntervalSince1970: 0))
        #expect(settings["foo"] as? Int == 1)
        #expect(settings["bar"] as? String == "x")
    }
    
    @Test
    func resolveAppliesScheduledOverrideOnlyWithinSchedule() throws {
        let sut = try makeService(variant: nil, json: scheduledJSON)
        #expect(sut.resolve(date: Date(timeIntervalSince1970: 0))["foo"] as? Int == 1)
        #expect(sut.resolve(date: Date(timeIntervalSince1970: 5400))["foo"] as? Int == 2)
        #expect(sut.resolve(date: Date(timeIntervalSince1970: 10800))["foo"] as? Int == 1)
    }
    
    @Test
    func nextResolutionDate() throws {
        let sut = try makeService(variant: nil, json: scheduledJSON)
        #expect(sut.nextResolutionDate(after: Date(timeIntervalSince1970: 0)) == Date(timeIntervalSince1970: 3600))
        #expect(sut.nextResolutionDate(after: Date(timeIntervalSince1970: 3600)) == Date(timeIntervalSince1970: 7200))
        #expect(sut.nextResolutionDate(after: Date(timeIntervalSince1970: 7200)) == nil)
    }
    
    @Test
    func nextResolutionDateIsNilWithoutSchedules() throws {
        let sut = try makeService(variant: nil)
        #expect(sut.nextResolutionDate(after: Date(timeIntervalSince1970: 0)) == nil)
    }
    
    @Test
    func bundledConfigIsAppliedOnInit() async throws {
        let (stream, continuation) = AsyncStream.makeStream(of: Bool?.self)
        _ = try makeService(variant: "AppStore") { settings in
            continuation.yield(settings["foo"] as? Bool)
        }
        var iterator = stream.makeAsyncIterator()
        let applied = await iterator.next()
        #expect(applied == .some(false))
    }
    
    @Test
    func missingConfigResolvesToEmptySettings() throws {
        let sut = try makeService(variant: nil, json: #"{ "settings": {} }"#)
        #expect(sut.resolve(date: Date(timeIntervalSince1970: 0)).isEmpty)
    }
}

final class LockedBox: @unchecked Sendable {
    private let lock = NSLock()
    private var _value: Bool?
    var value: Bool? { lock.withLock { _value } }
    func set(_ v: Bool?) { lock.withLock { _value = v } }
}
