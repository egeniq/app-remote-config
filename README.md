# AppRemoteConfig

Configure apps remotely: A simple but effective way to manage apps remotely.

Create a simple configuration file that is easy to maintain and host, yet provides important flexibility to specify settings based on your needs.

## Schema

The JSON/YAML schema is defined [here](https://raw.githubusercontent.com/egeniq/app-remote-config/main/Schema/appremoteconfig.schema.json).

## CLI Utility

Use the `care` CLI utility to initialize, verify, resolve and prepare configuration files.

To install use:

    brew install egeniq/app-utilities/care

## Multiplatform

### Swift

Import the package in your `Package.swift` file:

    .package(url: "https://github.com/egeniq/app-remote-config", from: "0.0.2"),

Then a good approach is to create your own `AppRemoteConfigClient`.

    // App Remote Config
    .target(
        name: "AppRemoteConfigClient",
        dependencies: [
            .product(name: "AppRemoteConfigMacros", package: "app-remote-config"),
            .product(name: "AppRemoteConfigService", package: "app-remote-config"),
            .product(name: "Dependencies", package: "swift-dependencies"),
            .product(name: "DependenciesAdditions", package: "swift-dependencies-additions"),
            .product(name: "DependenciesMacros", package: "swift-dependencies"),
            .product(name: "Perception", package: "swift-perception")
        ]
    )
        
Using these dependencies:

    .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.0.0"),
    .package(url: "https://github.com/pointfreeco/swift-perception", from: "1.0.0"),
    .package(url: "https://github.com/tgrapperon/swift-dependencies-additions", from: "1.0.0")
     
Then your `AppRemoteConfigClient.swift` is something like this:
        
    import AppRemoteConfigService
    import AppRemoteConfigMacros
    import Dependencies
    import DependenciesMacros
    import Foundation
    import Perception

    @AppRemoteConfigValues @Perceptible
    public class Values {
        public private(set) var updateRecommended: Bool = false
        public private(set) var updateRequired: Bool = false
    }

    @DependencyClient
    public struct AppRemoteConfigClient {
        public var values: () -> Values = { Values() }
    }

    extension DependencyValues {
        public var configClient: AppRemoteConfigClient {
            get { self[AppRemoteConfigClient.self] }
            set { self[AppRemoteConfigClient.self] = newValue }
        }
    }

    extension AppRemoteConfigClient: TestDependencyKey {
        public static let testValue = Self()
    }

    extension AppRemoteConfigClient: DependencyKey {
        public static let liveValue = {
            let url = URL(string: "https://www.example.com/config.json")!
            let values = Values()
            let service = AppRemoteConfigService(url: url, apply: values.apply(settings:))
            return Self(values: { values })
        }()
    }

### Android

Support for Android can be found [here](https://github.com/egeniq/app-remote-config-android).
