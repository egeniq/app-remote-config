# ConfigurationSharing

A module that integrates Swift Configuration with Swift Sharing, enabling reactive shared configuration state using the `@SharedReader` property wrapper.

## Overview

ConfigurationSharing provides a `ConfigurationKey` that conforms to Swift Sharing's `SharedReaderKey` protocol, allowing you to use configuration values with the `@SharedReader` property wrapper for reactive, observable configuration management.

## Features

- **Reactive Configuration**: Use `@SharedReader` to automatically observe configuration changes via `watchSnapshot`
- **Type-Safe Access**: Support for `String`, `Int`, `Double`, `Bool`, and `[String]` types
- **Provider Integration**: Works with any `ConfigProvider` from Swift Configuration
- **Dependency Injection**: Supports default readers via Swift Dependencies
- **Read-Only**: Configuration is read-only (as it should be for most use cases)
- **Async-Aware**: Handles async provider initialization through the `DefaultConfigurationReader` dependency

## Usage

### Basic Example with Default Provider

```swift
import ConfigurationSharing
import Sharing

// First, configure the default reader in your app init:
@main
struct MyApp: App {
    init() {
        prepareDependencies {
            $0.defaultConfigurationReader = DefaultConfigurationReader(initialize: {
                var logger = Logger(label: "com.example.config")
                logger.logLevel = .debug
                
                let provider = try await AppRemoteConfigProvider(
                    url: configURL,
                    pollInterval: .seconds(30),
                    resolutionContext: context,
                    logger: logger
                )
                
                // Return reader, services to manage, and logger
                // Services will be automatically managed in a ServiceGroup
                return (ConfigReader(providers: [provider]), [provider], logger)
            })
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

// Then use @SharedReader with configuration keys:
struct ContentView: View {
    @SharedReader(.configuration("apiEndpoint"))
    var apiEndpoint = "https://api.example.com"
    
    @SharedReader(.configuration("timeout"))
    var timeout = 30
    
    @SharedReader(.configuration("features.betaMode"))
    var betaMode = false
    
    var body: some View {
        VStack {
            Text("API: \($apiEndpoint.wrappedValue)")
            Text("Timeout: \($timeout.wrappedValue)")
            Text("Beta: \($betaMode.wrappedValue)")
        }
    }
}
```

### With a Specific Provider

```swift
import AppRemoteConfigProvider
import ConfigurationSharing
import Sharing

let provider = AppRemoteConfigProvider<JSONSnapshot>(/* ... */)
let reader = ConfigReader(providers: [provider])

@SharedReader(.configuration("features.newUI", reader: reader))
var newUI = false
```

### Setting a Default Provider via Dependencies

```swift
@main
struct MyApp: App {
    init() {
        prepareDependencies {
            $0.defaultConfigurationReader = DefaultConfigurationReader(initialize: {
                try await createMyConfigReader()
            })
        }
    }
}

private func createMyConfigReader() async throws -> (ConfigReader, [any Service]?, Logger?) {
    var logger = Logger(label: "com.example.config")
    logger.logLevel = .debug
    
    let provider = try await AppRemoteConfigProvider<JSONSnapshot>(
        url: configURL,
        pollInterval: .seconds(30),
        resolutionContext: context,
        logger: logger
    )
    
    // Return the reader, services that need lifecycle management, and logger
    // AppRemoteConfigProvider conforms to Service, so it will be managed automatically
    return (ConfigReader(providers: [provider]), [provider], logger)
}
```

## Architecture

### ConfigurationKey

The `ConfigurationKey<Value>` struct implements `SharedReaderKey` to bridge Swift Configuration and Swift Sharing:

- **`load()`**: Asynchronously initializes the reader and fetches the initial configuration value. If no value is found, it falls back to the `@SharedReader` default. This uses the continuation callback to resume asynchronously once the value is available.
- **`subscribe()`**: Sets up continuous watching of configuration changes via `watchSnapshot`. Updates are streamed to the `SharedSubscriber` as configuration changes occur.
- **`set()`**: No-op for read-only configuration.

### DefaultConfigurationReader

The `DefaultConfigurationReader` dependency provides an async factory pattern for initializing configuration readers with automatic service lifecycle management:

```swift
public struct DefaultConfigurationReader: Sendable {
    public var initialize: @Sendable () async throws -> (ConfigReader, [any Service]?, Logger?)
}
```

This allows you to:
1. Set up the initialization factory synchronously in `prepareDependencies`
2. Call the async factory when `@SharedReader` needs the reader
3. Handle complex async setup (network requests, file I/O, etc.)
4. Optionally pass services that conform to `Service` for automatic lifecycle management
5. The reader is cached after first initialization, so services run only once

## Type Support

ConfigurationSharing automatically supports reading these types from Configuration:

- `String`
- `Int`
- `Double`
- `Bool`
- `[String]`

Values are read from `ConfigSnapshotReader` using the appropriate typed method (`.string(forKey:)`, `.int(forKey:)`, etc.).

## Error Handling

- If the `defaultConfigurationReader` dependency is not configured, a `fatalError` is raised with a helpful message.
- If watching configuration fails, the value remains at its last known state.
- Missing configuration keys return `nil`, allowing the `@SharedReader` default to apply.
