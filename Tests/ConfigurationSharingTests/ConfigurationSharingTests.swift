import Configuration
import ConfigurationSharing
import Dependencies
import Sharing
import Testing

@Suite("ConfigurationSharing Tests")
struct ConfigurationSharingTests {
    
    @Test("ConfigurationKey loads value from provider")
    func testLoadValue() async throws {
        // Create a simple test provider
        let testProvider = TestConfigProvider(values: [
            "test.string": Configuration.ConfigValue("Hello", isSecret: false),
            "test.int": Configuration.ConfigValue(42, isSecret: false),
            "test.bool": Configuration.ConfigValue(true, isSecret: false),
        ])
        
        await withDependencies {
            $0.defaultConfigurationProvider = testProvider
        } operation: {
            let stringKey = ConfigurationKey("test.string", default: "default")
            let intKey = ConfigurationKey("test.int", default: 0)
            let boolKey = ConfigurationKey("test.bool", default: false)
            
            // Test load method
            var stringLoaded: String?
            var intLoaded: Int?
            var boolLoaded: Bool?
            
            stringKey.load(context: .userInitiated, continuation: LoadContinuation { result in
                stringLoaded = try? result.get()
            })
            
            intKey.load(context: .userInitiated, continuation: LoadContinuation { result in
                intLoaded = try? result.get()
            })
            
            boolKey.load(context: .userInitiated, continuation: LoadContinuation { result in
                boolLoaded = try? result.get()
            })
            
            #expect(stringLoaded == "Hello")
            #expect(intLoaded == 42)
            #expect(boolLoaded == true)
        }
    }
    
    @Test("ConfigurationKey returns default when value not found")
    func testDefaultValue() async throws {
        let emptyProvider = TestConfigProvider(values: [:])
        
        await withDependencies {
            $0.defaultConfigurationProvider = emptyProvider
        } operation: {
            let key = ConfigurationKey("nonexistent", default: "default")
            
            var loaded: String?
            key.load(context: .userInitiated, continuation: LoadContinuation { result in
                loaded = try? result.get()
            })
            
            #expect(loaded == "default")
        }
    }
    
    @Test("ConfigurationKey with explicit provider")
    func testExplicitProvider() async throws {
        let provider1 = TestConfigProvider(values: [
            "test.value": Configuration.ConfigValue("Provider1", isSecret: false)
        ])
        
        let provider2 = TestConfigProvider(values: [
            "test.value": Configuration.ConfigValue("Provider2", isSecret: false)
        ])
        
        let key1 = ConfigurationKey("test.value", default: "default", provider: provider1)
        let key2 = ConfigurationKey("test.value", default: "default", provider: provider2)
        
        var value1: String?
        var value2: String?
        
        key1.load(context: .userInitiated, continuation: LoadContinuation { result in
            value1 = try? result.get()
        })
        
        key2.load(context: .userInitiated, continuation: LoadContinuation { result in
            value2 = try? result.get()
        })
        
        #expect(value1 == "Provider1")
        #expect(value2 == "Provider2")
    }
    
    @Test("ConfigurationKey supports all types")
    func testAllTypes() async throws {
        let provider = TestConfigProvider(values: [
            "string": Configuration.ConfigValue("test", isSecret: false),
            "int": Configuration.ConfigValue(123, isSecret: false),
            "double": Configuration.ConfigValue(3.14, isSecret: false),
            "bool": Configuration.ConfigValue(false, isSecret: false),
            "stringArray": Configuration.ConfigValue(["a", "b", "c"], isSecret: false),
        ])
        
        await withDependencies {
            $0.defaultConfigurationProvider = provider
        } operation: {
            let stringKey = ConfigurationKey("string", default: "")
            let intKey = ConfigurationKey("int", default: 0)
            let doubleKey = ConfigurationKey("double", default: 0.0)
            let boolKey = ConfigurationKey("bool", default: true)
            let arrayKey = ConfigurationKey("stringArray", default: [String]())
            
            var stringValue: String?
            var intValue: Int?
            var doubleValue: Double?
            var boolValue: Bool?
            var arrayValue: [String]?
            
            stringKey.load(context: .userInitiated, continuation: LoadContinuation { result in
                stringValue = try? result.get()
            })
            
            intKey.load(context: .userInitiated, continuation: LoadContinuation { result in
                intValue = try? result.get()
            })
            
            doubleKey.load(context: .userInitiated, continuation: LoadContinuation { result in
                doubleValue = try? result.get()
            })
            
            boolKey.load(context: .userInitiated, continuation: LoadContinuation { result in
                boolValue = try? result.get()
            })
            
            arrayKey.load(context: .userInitiated, continuation: LoadContinuation { result in
                arrayValue = try? result.get()
            })
            
            #expect(stringValue == "test")
            #expect(intValue == 123)
            #expect(doubleValue == 3.14)
            #expect(boolValue == false)
            #expect(arrayValue == ["a", "b", "c"])
        }
    }
}

// Test provider for ConfigurationSharing tests
private struct TestConfigProvider: ConfigProvider {
    var providerName: String { "TestConfigProvider" }
    let values: [String: Configuration.ConfigValue]
    
    func value(forKey key: Configuration.AbsoluteConfigKey, type: Configuration.ConfigType) throws -> Configuration.LookupResult {
        let encodedKey = key.components.joined(separator: ".")
        let value = values[encodedKey]
        return Configuration.LookupResult(encodedKey: encodedKey, value: value)
    }
    
    func fetchValue(forKey key: Configuration.AbsoluteConfigKey, type: Configuration.ConfigType) async throws -> Configuration.LookupResult {
        try value(forKey: key, type: type)
    }
    
    func watchValue<Return>(
        forKey key: Configuration.AbsoluteConfigKey,
        type: Configuration.ConfigType,
        updatesHandler: nonisolated(nonsending) (Configuration.ConfigUpdatesAsyncSequence<Result<Configuration.LookupResult, any Error>, Never>) async throws -> Return
    ) async throws -> Return where Return : ~Copyable {
        let (stream, _) = AsyncStream<Result<Configuration.LookupResult, any Error>>.makeStream()
        return try await updatesHandler(.init(stream))
    }
    
    func snapshot() -> any Configuration.ConfigSnapshot {
        TestSnapshot(values: values, providerName: providerName)
    }
    
    func watchSnapshot<Return>(
        updatesHandler: nonisolated(nonsending) (Configuration.ConfigUpdatesAsyncSequence<any Configuration.ConfigSnapshot, Never>) async throws -> Return
    ) async throws -> Return where Return : ~Copyable {
        let (stream, _) = AsyncStream<any Configuration.ConfigSnapshot>.makeStream()
        return try await updatesHandler(.init(stream))
    }
}

private struct TestSnapshot: Configuration.ConfigSnapshot {
    let values: [String: Configuration.ConfigValue]
    let providerName: String
    
    func value(forKey key: Configuration.AbsoluteConfigKey, type: Configuration.ConfigType) throws -> Configuration.LookupResult {
        let encodedKey = key.components.joined(separator: ".")
        let value = values[encodedKey]
        return Configuration.LookupResult(encodedKey: encodedKey, value: value)
    }
}
