# SwiftUI Sharing Example

A SwiftUI example application demonstrating how to use **ConfigurationSharing** with the `@SharedReader` property wrapper for reactive configuration management.

## Overview

This example shows the modern approach to handling remote configuration using:
- **AppRemoteConfigProvider** - Loads and manages configuration files with scheduled resolution
- **ConfigurationSharing** - Bridges AppRemoteConfigProvider to Swift Sharing
- **@SharedReader** - Property wrapper for reactive, observable configuration values

## Key Differences from the Regular SwiftUI Example

### Before (swiftui-example)
```swift
class ContentViewViewModel: ObservableObject {
    @Published var betaMode: Bool = false
    
    private var snapshotWatcherTask: Task<Void, Never>?
    
    init(provider: AppRemoteConfigProvider<JSONSnapshot>) {
        self.provider = provider
        loadConfiguration()
        startWatchingSnapshot()
    }
    
    private func startWatchingSnapshot() {
        snapshotWatcherTask = Task {
            for await _ in provider.watchSnapshot() {
                await MainActor.run {
                    self.loadConfiguration()
                }
            }
        }
    }
    
    deinit {
        snapshotWatcherTask?.cancel()
    }
}

struct ContentView: View {
    @ObservedObject var viewModel: ContentViewViewModel
    
    var body: some View {
        Text(viewModel.betaMode ? "Beta Enabled" : "Beta Disabled")
    }
}
```

### After (swiftui-sharing-example)
```swift
struct ContentView: View {
    @SharedReader(.configuration("features.betaMode", default: false))
    var betaMode = false
    
    var body: some View {
        Text(betaMode ? "Beta Enabled" : "Beta Disabled")
    }
}
```

**Benefits:**
- ✅ No ViewModel boilerplate
- ✅ No manual task management
- ✅ No deinit cleanup needed
- ✅ Cleaner, more readable code
- ✅ Automatic updates across all views using the same configuration

## Features Demonstrated

1. **Automatic Platform Detection** - Detects iOS, macOS, tvOS, or watchOS
2. **Version Reading** - Reads app version from Info.plist
3. **Build Variant Detection** - Determines DEBUG vs RELEASE builds
4. **Configuration Polling** - Polls configuration file every 30 seconds
5. **Scheduled Overrides** - Features activate/deactivate at scheduled times
6. **Reactive Updates** - Views automatically update when configuration changes
7. **ConfigurationSharing Integration** - Uses @SharedReader for effortless reactivity

## Configuration Structure

The example creates a configuration file with:

```json
{
  "settings": {
    "appName": "Swift Sharing Configuration Example",
    "features": {
      "betaMode": false,
      "newUI": false,
      "darkMode": true
    },
    "apiEndpoint": "https://api.example.com/v1",
    "timeout": 30,
    "maxRetries": 3
  },
  "overrides": [
    {
      "schedule": {
        "from": "2024-...",
        "until": "2024-..."
      },
      "settings": {
        "features": {
          "betaMode": true,
          "newUI": true,
          "darkMode": true
        }
      }
    }
  ]
}
```

Features in the scheduled `overrides` section will automatically activate at the specified time and update all @SharedReader properties.

## Architecture

```
┌──────────────────┐
│ swiftui-sharing- │
│    example       │
└────────┬─────────┘
         │
         ├─── AppRemoteConfigProvider ────┐
         │   (loads + polls config)       │
         │                                │
         ├─── Shares to Dependencies ─────┤
         │  (as defaultConfigurationProvider)
         │                                │
         └─── ConfigurationSharing ───────┤
             (provides @SharedReader)      │
                 │                        │
                 └─ ContentView ──────────┘
                    (reads via @SharedReader)
```

## Usage

1. **Build the project:**
   ```bash
   cd Examples/swiftui-sharing-example
   swift build
   ```

2. **Run the app:**
   ```bash
   swift run SwiftUISharingExample
   ```

3. **Observe changes:**
   - Features will toggle at the scheduled times
   - No manual refresh needed
   - All views automatically re-render
   - Configuration polling happens in background

## Configuration Updates

Configuration automatically updates in two scenarios:

1. **Polling Interval** - Every 30 seconds, the provider checks the file
2. **Scheduled Overrides** - At scheduled times, features enable/disable automatically

When either occurs, all `@SharedReader` properties update and views re-render.

## Comparison with Other Examples

- **hello-world-example**: Basic configuration reading without UI
- **swiftui-example**: Direct provider access with manual ViewModel management
- **swiftui-sharing-example**: Modern approach using @SharedReader (this example)

## Advanced Features

### Nested Keys

Access nested configuration values using dot notation:

```swift
@SharedReader(.configuration("features.newUI", default: false))
var newUI: Bool

@SharedReader(.configuration("apiEndpoint", default: "https://default.example.com"))
var apiEndpoint: String
```

### Type Support

ConfigurationSharing supports:
- `String`
- `Int`
- `Double`
- `Bool`
- `[String]`

### Custom Provider

You can use a different provider:

```swift
@SharedReader(.configuration("key", default: "value", provider: customProvider))
var value: String
```

## Next Steps

- Explore scheduled overrides by modifying the time range in `createExampleConfigFile()`
- Add more configuration values to the example JSON
- Use multiple `@SharedReader` properties to manage complex state
- Combine with other Swift Sharing strategies for hybrid persistence

## See Also

- [ConfigurationSharing README](../../Sources/ConfigurationSharing/README.md)
- [AppRemoteConfigProvider](../../Sources/AppRemoteConfigProvider)
- [Swift Sharing Documentation](https://github.com/pointfreeco/swift-sharing)
- [Swift Configuration Documentation](https://github.com/apple/swift-configuration)
