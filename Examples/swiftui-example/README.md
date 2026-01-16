# SwiftUI Remote Configuration Example

This example demonstrates how to integrate `AppRemoteConfigProvider` into a SwiftUI application, showing best practices for configuration management and state handling.

## Overview

The example app shows:
- **Provider Initialization**: Setting up `AppRemoteConfigProvider` with resolution context
- **ServiceGroup Integration**: Running provider as a service to enable automatic polling
- **Foreground Refresh**: Automatically refreshes configuration when app returns to foreground
- **Logging**: Using `swift-log` Logger to see provider activity in console
- **Configuration Management**: Reading and displaying remote configuration values
- **SwiftUI Integration**: Using `@ObservedObject` and state management to display config values
- **Error Handling**: Gracefully handling initialization failures
- **Dynamic Updates**: Refreshing configuration on demand

## Key Components

### `App.swift` - Application Entry Point
- Automatically detects platform using `#if os()` compiler directives
- Reads app version from `Info.plist` (`CFBundleShortVersionString`)
- Determines build variant from `DEBUG` flag
- Fetches OS version once using `ProcessInfo.processInfo.operatingSystemVersion`
- Creates a Logger instance to track provider activity
- Sets up ServiceGroup to run the provider as a service (enables polling)
- Monitors scene phase to refresh configuration when app comes to foreground
- Demonstrates async provider instantiation with error handling
- Logs initialization details for debugging

### ResolutionContext Configuration

The example shows how to automatically populate `ResolutionContext`:

```swift
// Automatically detect platform
#if os(iOS)
let platform = Platform.iOS
#elseif os(macOS)
let platform = Platform.macOS
#elseif os(tvOS)
let platform = Platform.tvOS
#elseif os(watchOS)
let platform = Platform.watchOS
#endif

// Fetch OS version once
let osVersion = ProcessInfo.processInfo.operatingSystemVersion

// Read app version from Info.plist
let appVersionString = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
let appVersion = try Version(appVersionString)

// Determine build variant from DEBUG flag
#if DEBUG
let buildVariant = BuildVariant.debug
#else
let buildVariant = BuildVariant.release
#endif

let resolutionContext = AppRemoteConfigProvider<JSONSnapshot>.ResolutionContext(
    platform: platform,
    platformVersion: osVersion,
    appVersion: appVersion,
    variant: nil,                          // Optional variant for A/B testing
    buildVariant: buildVariant,
    language: Locale.current.language.languageCode?.identifier
)
```

### AppRemoteConfigProvider Instantiation

```swift
let provider = try await AppRemoteConfigProvider<JSONSnapshot>(
    url: configFileURL,
    pollInterval: .seconds(30),            // Poll interval (nil to disable)
    minimumRefreshInterval: .seconds(5),   // Minimum wait between refreshes
    resolutionContext: resolutionContext
)
```

### `ContentViewViewModel.swift` - State Management
- `@MainActor` class managing provider state
- Exposes configuration values as `@Published` properties
- Provides methods for refreshing and updating configuration
- Integrates with `ConfigReader` for typed value access

### `ContentView.swift` - User Interface
- Displays configuration values in organized sections
- Feature toggles with visual indicators
- API configuration settings
- Refresh button with loading state
- Reusable components: `FeatureToggleRow`, `ConfigurationItemRow`, `Badge`

## Configuration Structure

The example uses this JSON structure:
```json
{
    "settings": {
        "appName": "My App",
        "features": {
            "betaMode": true,
            "newUI": true,
            "darkMode": true
        },
        "apiEndpoint": "https://api.example.com",
        "timeout": 30,
        "maxRetries": 3
  },
    "overrides": []
}
```

## Running the Example

### Prerequisites
- Xcode 15.0 or later
- iOS 17.0 or later deployment target
- Swift 5.9 or later

### Build and Run
```bash
cd Examples/swiftui-example
xcodebuild -scheme SwiftUIExample -destination 'platform=iOS Simulator,name=iPhone 15'
```

Or open in Xcode:
```bash
open -a Xcode SwiftUIExample.xcodeproj
```

## Logging

The example includes logging to help developers understand what the provider is doing:

```swift
import Logging

var logger = Logger(label: "com.example.remoteconfig")
logger.logLevel = .debug  // Set to .info, .debug, .trace, etc.
```

When running the app, you'll see log output like:
- Provider initialization
- Configuration file reads
- Polling activity
- Refresh operations
- Error conditions

To view logs:
- **Xcode**: Open the Console (⌘⇧Y) when running the app
- **Terminal**: Logs appear in stdout when running via `swift run`

Log levels:
- `.trace`: Very detailed debugging information
- `.debug`: Detailed information useful during development
- `.info`: General informational messages (recommended)
- `.warning`: Warning messages
- `.error`: Error messages only

## Key Integration Points

### 1. Provider Initialization with Automatic Detection
```swift
// Automatically detect platform based on compilation target
#if os(iOS)
let platform = Platform.iOS
#elseif os(macOS)
let platform = Platform.macOS
// ... etc
#endif

// Fetch OS version once
let osVersion = ProcessInfo.processInfo.operatingSystemVersion

// Read version from Info.plist
let appVersionString = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
let appVersion = try Version(appVersionString)

// Detect build variant from DEBUG flag
#if DEBUG
let buildVariant = BuildVariant.debug
#else
let buildVariant = BuildVariant.release
#endif

// Create resolution context with detected values
let resolutionContext = AppRemoteConfigProvider<JSONSnapshot>.ResolutionContext(
    platform: platform,
    platformVersion: osVersion,
    appVersion: appVersion,
    variant: nil,
    buildVariant: buildVariant,
    language: Locale.current.language.languageCode?.identifier
)

// Create a logger to see provider activity in console
var logger = Logger(label: "com.example.remoteconfig")
logger.logLevel = .debug  // Set to .debug to see detailed activity

// Instantiate the provider with logger
let provider = try await AppRemoteConfigProvider<JSONSnapshot>(
    url: configFileURL,
    pollInterval: .seconds(30),
    minimumRefreshInterval: .seconds(5),
    resolutionContext: resolutionContext,
    logger: logger
)

// Log initialization details
logger.info("AppRemoteConfigProvider initialized successfully")
logger.info("Platform: \(platform), OS: \(osVersion.majorVersion).\(osVersion.minorVersion)")
logger.info("App version: \(appVersion), Build variant: \(buildVariant)")

// Create ServiceGroup to run the provider (required for polling to work)
let serviceGroup = ServiceGroup(
    services: [provider],
    logger: logger
)

// Start the service group in a background task
Task {
    try await serviceGroup.run()
}
```

### 2. ServiceGroup for Automatic Polling

**Important**: The provider implements the `Service` protocol and must be run within a `ServiceGroup` to enable automatic polling and reloading:

```swift
import ServiceLifecycle

// Create the service group with the provider
let serviceGroup = ServiceGroup(
    services: [provider],
    logger: logger
)

// Run the service group (this enables the pollInterval functionality)
Task {
    do {
        try await serviceGroup.run()
    } catch {
        logger.error("ServiceGroup error: \(error)")
    }
}
```

Without the ServiceGroup, the provider will only load the configuration once at initialization and won't poll for updates.

### 3. Foreground Refresh

The example automatically refreshes configuration when the app returns to the foreground using SwiftUI's scene phase monitoring:

```swift
@Environment(\.scenePhase) private var scenePhase

var body: some Scene {
    WindowGroup {
        // ... your content ...
    }
    .onChange(of: scenePhase) { oldPhase, newPhase in
        if newPhase == .active {
            // Refresh configuration when app comes to foreground
            Task {
                await viewModel?.refresh()
            }
        }
    }
}
```

This ensures users always get the latest configuration when:
- Returning from background
- Switching back from another app
- Unlocking the device

The refresh respects the `minimumRefreshInterval` to avoid excessive API calls.

### 4. Reading Configuration Values
```swift
// Access provider through ConfigReader
let reader = ConfigReader(provider: provider)
let endpoint = reader.string(forKey: "apiEndpoint", default: "...")
let timeout = reader.int(forKey: "timeout", default: 30)
let betaMode = reader.bool(forKey: "features.betaMode", default: false)
```

### 5. SwiftUI State Binding
```swift
@ObservedObject var viewModel: ContentViewViewModel

// Update when configuration changes
Task {
    await viewModel.refresh()
}
```

## Configuration Resolution

The app uses the following resolution context:
- **Platform**: iOS
- **App Version**: 1.0.0
- **Build Variant**: Debug
- **Language**: System locale

You can modify these in `App.swift` to test different configuration variants.

## Error Handling

The app handles several error scenarios:
- **Initialization Failures**: Displayed in the `ErrorView`
- **Missing Configuration Files**: Gracefully handled with defaults
- **Refresh Failures**: Logged but don't affect current state
- **Malformed JSON**: Handled by `JSONSerialization`

## Next Steps

To extend this example:
1. Replace the temporary file with actual remote URL
2. Add authentication for remote configurations
3. Implement configuration caching
4. Add signing and verification
5. Create more complex UI showing nested configuration structures

## Learn More

- See the main project README for more information about AppRemoteConfigProvider
- Review `AppRemoteConfigProviderTests` for testing patterns
- Check `Configuration` framework documentation for typed value reading
