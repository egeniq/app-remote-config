// swift-tools-version: 5.9

import Foundation
import PackageDescription

let package = Package(
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
