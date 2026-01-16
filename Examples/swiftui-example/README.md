# SwiftUI Remote Configuration Example

This example demonstrates how to integrate `AppRemoteConfigProvider` into a SwiftUI application, showing best practices for configuration management and state handling.

## Overview

The example app shows:
- **Provider Initialization**: Setting up `AppRemoteConfigProvider` with resolution context
- **Configuration Management**: Reading and displaying remote configuration values
- **SwiftUI Integration**: Using `@ObservedObject` and state management to display config values
- **Error Handling**: Gracefully handling initialization failures
- **Dynamic Updates**: Refreshing configuration on demand

## Key Components

### `App.swift` - Application Entry Point
- Initializes the `AppRemoteConfigProvider` with proper `ResolutionContext`
- Creates and writes example configuration JSON file
- Demonstrates async provider instantiation with error handling
- Shows proper resolution context setup with platform, version, and language

### ResolutionContext Configuration

The example shows how to populate `ResolutionContext` with:

```swift
let resolutionContext = AppRemoteConfigProvider<JSONSnapshot>.ResolutionContext(
    platform: .iOS,                        // Device platform
    platformVersion: OperatingSystemVersion(
        majorVersion: 17,                  // OS version
        minorVersion: 0,
        patchVersion: 0
    ),
    appVersion: try Version("1.0.0"),     // App version for variant selection
    variant: nil,                          // Optional variant for A/B testing
    buildVariant: .debug,                 // Debug or Release build
    language: Locale.current.language.languageCode?.identifier  // User language
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
  "appName": "My App",
  "features": {
    "betaMode": true,
    "newUI": true,
    "darkMode": true
  },
  "apiEndpoint": "https://api.example.com",
  "timeout": 30,
  "maxRetries": 3
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

## Key Integration Points

### 1. Provider Initialization
```swift
// Create resolution context with platform and app information
let resolutionContext = AppRemoteConfigProvider<JSONSnapshot>.ResolutionContext(
    platform: .iOS,
    platformVersion: OperatingSystemVersion(majorVersion: 17, minorVersion: 0, patchVersion: 0),
    appVersion: try Version("1.0.0"),
    variant: nil,
    buildVariant: .debug,
    language: Locale.current.language.languageCode?.identifier
)

// Instantiate the provider
let provider = try await AppRemoteConfigProvider<JSONSnapshot>(
    url: configFileURL,
    pollInterval: .seconds(30),
    minimumRefreshInterval: .seconds(5),
    resolutionContext: resolutionContext
)
```

### 2. Reading Configuration Values
```swift
// Access provider through ConfigReader
let reader = ConfigReader(provider: provider)
let endpoint = reader.string(forKey: "apiEndpoint", default: "...")
let timeout = reader.int(forKey: "timeout", default: 30)
let betaMode = reader.bool(forKey: "features.betaMode", default: false)
```

### 3. SwiftUI State Binding
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
