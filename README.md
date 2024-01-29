# AppRemoteConfig

Configure apps remotely: A simple but effective way to manage apps remotely.

Create a simple configuration file that is easy to maintain and host, yet provides important flexibility to specify settings based on your needs.

## Schema

The JSON/YAML schema is defined [here](./Schema/appremoteconfig.schema.json).

## CLI Utility

Use the `care` CLI utility to initialize, verify, resolve and prepare configuration files.

## Multiplatform

### Swift

Import the package in your `Package.swift` file:

    .package(url: "https://github.com/egeniq/app-remote-config", branch: "develop"),

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

WORK IN PROGRESS

Rename Package.swift to Package-Backup.swift.

Rename Package-Android.swift to Package.swift.

You can compile the `AppRemoteConfig` module for Android using [Scade](https://www.scade.io).

    /Applications/Scade.app/Contents/PlugIns/ScadeSDK.plugin/Contents/Resources/Libraries/scd/bin/scd \
        archive \
        --type android-aar \
        --path . \
        --platform android-arm64-v8a \
        --platform android-x86_64 \
        --android-ndk ~/Library/Android/sdk/ndk/26.1.10909125 \
        --generate-android-manifest \
        --android-gradle /Applications/Scade.app/Contents/PlugIns/ScadeSDK.plugin/Contents/Resources/Libraries/ScadeSDK/thirdparty/gradle
