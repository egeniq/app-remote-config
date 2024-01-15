// swift-tools-version: 5.9
// This contains a Skip (https://skip.tools) package,
// containing a Swift Package Manager project
// that will use the Skip build plugin to transpile the
// Swift Package, Sources, and Tests into an
// Android Gradle Project with Kotlin sources and JUnit tests.
import PackageDescription
import Foundation

/* Default approach
// Set SKIP_ZERO=1 to build without Skip libraries
let zero = ProcessInfo.processInfo.environment["SKIP_ZERO"] != nil
*/

// The default approach means upstream defaults to using Skip, which we don't want.
// Set USE_SKIP=1 to build with Skip libraries
let useSkip = ProcessInfo.processInfo.environment["USE_SKIP"] != nil
let zero = !useSkip

let skipstone = !zero ? [Target.PluginUsage.plugin(name: "skipstone", package: "skip")] : []

let package = Package(
    name: "app-remote-config",
    defaultLocalization: "en",
    platforms: [.iOS(.v15), .macOS(.v13), .tvOS(.v16), .watchOS(.v9), .macCatalyst(.v16)],
    products: [
        .library(
            name: "AppRemoteConfig",
            targets: ["AppRemoteConfig"]
        ),
        .library(
            name: "AppRemoteConfigService",
            targets: ["AppRemoteConfigService"]
        ),
        .executable(
            name: "care",
            targets: ["care"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.0.0"),
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.0.6"),
        .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.0.0"),
        .package(url: "https://github.com/tgrapperon/swift-dependencies-additions", from: "1.0.0"),
        .package(url: "https://source.skip.tools/skip-foundation.git", from: "0.0.0"),
        .package(url: "https://source.skip.tools/skip.git", from: "0.7.45"),
    ],
    targets: [
        .target(
            name: "AppRemoteConfig",
            dependencies: (zero ? [] : [.product(name: "SkipFoundation", package: "skip-foundation")]),
            plugins: skipstone
        ),
        .testTarget(
            name: "AppRemoteConfigTests",
            dependencies: ["AppRemoteConfig"] + (zero ? [] : [.product(name: "SkipTest", package: "skip")]),
            plugins: skipstone
        ),
        .target(
            name: "AppRemoteConfigService",
            dependencies: [
                "AppRemoteConfig",
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "DependenciesAdditions", package: "swift-dependencies-additions")
            ]),
        .executableTarget(
            name: "care",
            dependencies: [
                "AppRemoteConfig",
                .product(name: "Yams", package: "Yams"),
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]),
    ]
)
