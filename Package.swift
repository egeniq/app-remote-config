// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "AppRemoteConfig",
    defaultLocalization: "en",
    platforms: [.iOS(.v15), .macOS(.v12), .tvOS(.v15), .watchOS(.v8), .macCatalyst(.v15)],
    products: [
        .library(
            name: "AppRemoteConfig",
            targets: ["AppRemoteConfig"]
        )
    ],
    targets: [
        .target(
            name: "AppRemoteConfig"
        ),
        .testTarget(
            name: "AppRemoteConfigTests",
            dependencies: [
                "AppRemoteConfig"
            ]
        )
    ]
)
