// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "AppRemoteConfig",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15),
        .tvOS(.v13),
        .watchOS(.v6)
    ],
    products: [
        .library(
            name: "AppRemoteConfig",
            targets: ["AppRemoteConfig"]
        ),
        .library(
            name: "SodiumClientLive",
            targets: ["SodiumClientLive"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.0.0"),
        .package(url: "https://github.com/jedisct1/swift-sodium.git", from: "0.9.1")
    ],
    targets: [
        .target(
            name: "AppRemoteConfig",
            dependencies: [
                "SodiumClient"
            ]
        ),
        .testTarget(
            name: "AppRemoteConfigTests",
            dependencies: [
                "AppRemoteConfig",
                "SodiumClientLive"
            ]
        ),
        .target(
            name: "SodiumClient",
            dependencies: [
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "DependenciesMacros", package: "swift-dependencies")
            ]
        ),
        .target(
            name: "SodiumClientLive",
            dependencies: [
                "SodiumClient",
                .product(name: "Sodium", package: "swift-sodium", condition: .when(platforms: [.iOS, .macOS, .tvOS, .watchOS]))
            ])
    ]
)
