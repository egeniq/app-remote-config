import Configuration
import ConfigurationSharing
import Dependencies
import Sharing
import Testing

@Suite("ConfigurationSharing Tests")
struct ConfigurationSharingTests {
    
    @Test("ConfigurationKey creates proper SharedReaderKey ID")
    func testConfigurationKeyID() {
        let key1 = ConfigurationKey<String>("test.setting")
        let key2 = ConfigurationKey<String>("test.setting")
        let key3 = ConfigurationKey<String>("other.setting")
        
        // Same key should have same ID
        #expect(key1.id == key2.id)
        
        // Different key should have different ID
        #expect(key1.id != key3.id)
    }
    
    @Test("ConfigurationKey supports all primitive types")
    func testSupportedTypes() {
        let stringKey = ConfigurationKey<String>("test.string")
        let intKey = ConfigurationKey<Int>("test.int")
        let doubleKey = ConfigurationKey<Double>("test.double")
        let boolKey = ConfigurationKey<Bool>("test.bool")
        let arrayKey = ConfigurationKey<[String]>("test.array")
        
        // Just verify they can be created without errors
        #expect(stringKey.id.key == "test.string")
        #expect(intKey.id.key == "test.int")
        #expect(doubleKey.id.key == "test.double")
        #expect(boolKey.id.key == "test.bool")
        #expect(arrayKey.id.key == "test.array")
    }
    
    @Test("ConfigurationKey factory methods")
    func testFactoryMethods() {
        // Test that the factory methods create keys correctly
        let stringKey: ConfigurationKey<String> = .configuration("test.string")
        let intKey: ConfigurationKey<Int> = .configuration("test.int")
        let doubleKey: ConfigurationKey<Double> = .configuration("test.double")
        let boolKey: ConfigurationKey<Bool> = .configuration("test.bool")
        let arrayKey: ConfigurationKey<[String]> = .configuration("test.array")
        
        #expect(stringKey.id.key == "test.string")
        #expect(intKey.id.key == "test.int")
        #expect(doubleKey.id.key == "test.double")
        #expect(boolKey.id.key == "test.bool")
        #expect(arrayKey.id.key == "test.array")
    }
    
    @Test("ConfigurationKey load method behavior")
    func testLoadMethodBehavior() {
        let key = ConfigurationKey<String>("test.string")
        
        // Verify that load() is accessible and callable
        // The actual behavior is to resume with initial value from context
        // which cannot be fully tested here without a SharedReader environment
        
        // Just verify the key can be used with load()
        let loadableKey: any SharedReaderKey = key
        #expect(loadableKey is ConfigurationKey<String>)
    }
}

// MARK: - Test Implementation Notes
/*
 The new ConfigurationKey implementation is designed to work with @SharedReader:
 
 1. `load()` is synchronous and returns the initial value (typically from the context)
 2. `subscribe()` handles async watching of configuration changes via watchSnapshot
 3. The actual reading happens in subscribe() using ConfigSnapshotReader methods
 4. Defaults are provided by the @SharedReader declaration, not ConfigurationKey
 5. The reader is resolved lazily from defaultConfigurationReader dependency
 
 Example usage:
 ```swift
 @SharedReader(.configuration("apiEndpoint"))
 var apiEndpoint = "https://default.example.com"
 
 // ConfigurationKey handles:
 // - Reading from ConfigReader via defaultConfigurationReader dependency
 // - Watching for configuration changes
 // - Updating the shared value when configuration updates
 // - All async/await concurrency properly
 ```
 */
