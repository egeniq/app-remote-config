# ConfigurationSharing

A module that integrates Swift Configuration with Swift Sharing, enabling reactive shared configuration state using the `@Shared` property wrapper.

## Overview

ConfigurationSharing provides a `ConfigurationKey` that conforms to Swift Sharing's `SharedReaderKey` protocol, allowing you to use configuration values with the `@Shared` property wrapper for reactive, observable configuration management.

## Features

- **Reactive Configuration**: Use `@Shared` to automatically observe configuration changes
- **Type-Safe Access**: Support for `String`, `Int`, `Double`, `Bool`, and `[String]` types
- **Provider Integration**: Works with any `ConfigProvider` from Swift Configuration
- **Dependency Injection**: Supports default providers via Swift Dependencies
- **Read-Only**: Configuration is read-only (as it should be for most use cases)

## Usage

### Basic Example

```swift
import ConfigurationSharing
import Sharing

// Use with a default value
@Shared(.configuration("apiEndpoint", default: "https://api.example.com"))
var apiEndpoint: String

@Shared(.configuration("timeout", default: 30))
var timeout: Int

@Shared(.configuration("features.betaMode", default: false))
var betaMode: Bool
```

### With a Specific Provider

```swift
import AppRemoteConfigProvider
import ConfigurationSharing
import Sharing

let provider = AppRemoteConfigProvider<JSONSnapshot>(/* ... */)

@Shared(.configuration("features.newUI", default: false, provider: provider))
var newUI: Bool
```

### Setting a Default Provider

Set a default configuration provider at app startup using Swift Dependencies:

```swift
import Dependencies
import ConfigurationSharing

@main
struct MyApp: App {
    init() {
        prepareDependencies {
            $0.defaultConfigurationProvider = myConfigProvider
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

Then use `@Shared` without specifying a provider:

```swift
@Shared(.configuration("features.darkMode", default: false))
var darkMode: Bool
```

## Automatic Updates

The `ConfigurationKey` automatically subscribes to changes in the underlying configuration provider. When the configuration changes (e.g., from a remote update or file change), all `@Shared` properties backed by that configuration will update automatically.

```swift
struct SettingsView: View {
    @Shared(.configuration("features.betaMode", default: false))
    var betaMode: Bool
    
    var body: some View {
        Toggle("Beta Mode", isOn: $betaMode)
            // Note: Setting the value won't save it (read-only)
            // This toggle will reflect the current config value
            // and update automatically when the config changes
    }
}
```

## Supported Types

The following types are supported via the `ConfigValue` protocol:

- `String`
- `Int`
- `Double`
- `Bool`
- `[String]`

## Integration with AppRemoteConfigProvider

ConfigurationSharing works seamlessly with `AppRemoteConfigProvider`:

```swift
import AppRemoteConfig
import AppRemoteConfigProvider
import ConfigurationSharing
import ServiceLifecycle
import Sharing

@main
struct MyApp: App {
    let serviceGroup = ServiceGroup(
        configuration: .init(
            services: [provider],
            gracefulShutdownSignals: [.sigterm, .sigint]
        ),
        logger: logger
    )
    
    let provider = AppRemoteConfigProvider<JSONSnapshot>(
        configFileURL: /* ... */,
        context: /* ... */,
        pollInterval: .seconds(30)
    )
    
    init() {
        prepareDependencies {
            $0.defaultConfigurationProvider = provider
        }
        
        Task {
            try await serviceGroup.run()
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    @Shared(.configuration("features.newUI", default: false))
    var newUI: Bool
    
    var body: some View {
        if newUI {
            NewUIView()
        } else {
            LegacyUIView()
        }
    }
}
```

When the configuration file updates (or a scheduled override triggers), the `newUI` binding will automatically update and the view will re-render.

## Comparison with Direct Provider Access

### Without ConfigurationSharing

```swift
class ViewModel: ObservableObject {
    @Published var newUI: Bool = false
    private var snapshotWatcherTask: Task<Void, Never>?
    
    func startWatching(provider: AppRemoteConfigProvider<JSONSnapshot>) {
        snapshotWatcherTask = Task { @MainActor in
            for await snapshot in provider.watchSnapshot() {
                let reader = ConfigSnapshotReader(snapshot: snapshot)
                newUI = reader.bool(forKey: "features.newUI", default: false)
            }
        }
    }
    
    deinit {
        snapshotWatcherTask?.cancel()
    }
}
```

### With ConfigurationSharing

```swift
struct ContentView: View {
    @Shared(.configuration("features.newUI", default: false))
    var newUI: Bool
    
    // That's it! No manual watching, no task management, no deinit
}
```

## Implementation Details

- **Read-Only**: The `save()` operation is a no-op since configuration is typically read-only
- **Thread-Safe**: Uses Swift Dependencies for safe provider management
- **Memory Efficient**: Subscriptions are automatically cleaned up when views disappear
- **Empty Provider**: Provides a safe empty provider when no default is configured

## See Also

- [Swift Configuration](https://github.com/apple/swift-configuration) - The underlying configuration library
- [Swift Sharing](https://github.com/pointfreeco/swift-sharing) - The reactive state sharing library
- [AppRemoteConfigProvider](../AppRemoteConfigProvider/README.md) - File-based configuration provider with scheduled resolution
