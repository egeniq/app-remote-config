// swift-tools-version: 5.9
import PackageDescription
import Foundation

let android = ProcessInfo.processInfo.environment["ANDROID"] == "1"

let package: Package

if android {
    package = Package(
        name: "AppRemoteConfig",
        defaultLocalization: "en",
        products: [
            .library(
                name: "AppRemoteConfig",
                targets: ["AppRemoteConfig"]
            ),
            .library(
                name: "AppRemoteConfigAndroid",
                type: .dynamic,
                targets: ["AppRemoteConfigAndroid"]
            )
        ],
        dependencies: [
            .package(url: "https://github.com/scade-platform/swift-java.git", branch: "main")
        ],
        targets: [
            .target(
                name: "AppRemoteConfig"
            ),
            .testTarget(
                name: "AppRemoteConfigTests",
                dependencies: ["AppRemoteConfig"]
            ),
            .target(
                name: "AppRemoteConfigAndroid",
                dependencies: [
                    "AppRemoteConfig",
                    .product(name: "Java", package: "swift-java")
                ])
        ]
    )
} else {
    package = Package(
        name: "AppRemoteConfig",
        defaultLocalization: "en",
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
            .package(url: "https://github.com/tgrapperon/swift-dependencies-additions", from: "1.0.0")
        ],
        targets: [
            .target(
                name: "AppRemoteConfig"
            ),
            .testTarget(
                name: "AppRemoteConfigTests",
                dependencies: ["AppRemoteConfig"]
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
}
