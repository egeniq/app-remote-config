// swift-tools-version: 5.9

import CompilerPluginSupport
import Foundation
import PackageDescription

let package = Package(
    name: "AppRemoteConfig",
    defaultLocalization: "en",
    platforms: [.iOS(.v15), .macOS(.v13), .tvOS(.v16), .watchOS(.v9), .macCatalyst(.v16)],
    products: [
        .library(
            name: "AppRemoteConfig",
            targets: ["AppRemoteConfig"]
        ),
        .library(
            name: "AppRemoteConfigMacros",
            targets: ["AppRemoteConfigMacros"]
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
        .package(url: "https://github.com/apple/swift-syntax", from: "509.0.0"),
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.0.6"),
        .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.0.0"),
        .package(url: "https://github.com/pointfreeco/swift-macro-testing", from: "0.2.0"),
        .package(url: "https://github.com/pointfreeco/xctest-dynamic-overlay", from: "1.0.0"),
        .package(url: "https://github.com/tgrapperon/swift-dependencies-additions", from: "1.0.0")
    ],
    targets: [
        .target(
            name: "AppRemoteConfig"
        ),
        .testTarget(
            name: "AppRemoteConfigTests",
            dependencies: [
                "AppRemoteConfig",
                "AppRemoteConfigMacros"
            ]
        ),
        .target(
            name: "AppRemoteConfigMacros",
            dependencies: [
                "AppRemoteConfigMacrosPlugin",
                .product(name: "XCTestDynamicOverlay", package: "xctest-dynamic-overlay"),
            ]
        ),
        .macro(
            name: "AppRemoteConfigMacrosPlugin",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
            ]
        ),
        .testTarget(
            name: "AppRemoteConfigMacrosPluginTests",
            dependencies: [
                "AppRemoteConfigMacrosPlugin",
                .product(name: "MacroTesting", package: "swift-macro-testing"),
            ]
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
