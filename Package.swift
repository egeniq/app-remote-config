// swift-tools-version: 6.2

import CompilerPluginSupport
import Foundation
import PackageDescription

let package = Package(
    name: "AppRemoteConfig",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v13),
        .macOS(.v15),
        .tvOS(.v13),
        .watchOS(.v6)
    ],
    products: [
        .library(
            name: "AppRemoteConfig",
            targets: ["AppRemoteConfig"]
        ),
        .library(
            name: "AppRemoteConfigProvider",
            targets: ["AppRemoteConfigProvider"]
        ),
        .library(
            name: "AppRemoteConfigService",
            targets: ["AppRemoteConfigService"]
        ),
        .library(
            name: "AppRemoteConfigServiceMacros",
            targets: ["AppRemoteConfigServiceMacros"]
        ),
        .executable(
            name: "care",
            targets: ["care"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-configuration.git", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-crypto.git", "1.0.0" ..< "4.0.0"),
//        .package(url: "https://github.com/apple/swift-log.git", from: "1.0.0"),
//        .package(url: "https://github.com/apple/swift-metrics", from: "2.7.0"),
//        .package(url: "https://github.com/jpsim/Yams.git", from: "5.0.6"),
        .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.0.0"),
        .package(url: "https://github.com/pointfreeco/swift-macro-testing", from: "0.6.0"),
        .package(url: "https://github.com/pointfreeco/xctest-dynamic-overlay", from: "1.0.0"),
        .package(url: "https://github.com/swiftlang/swift-syntax", "509.0.0"..<"603.0.0"),

//
//            .package(url: "https://github.com/apple/swift-system", from: "1.5.0"),
//            .package(url: "https://github.com/apple/swift-collections", from: "1.3.0"),
            .package(url: "https://github.com/swift-server/swift-service-lifecycle", from: "2.7.0"),
            .package(url: "https://github.com/apple/swift-log", from: "1.6.3"),
            .package(url: "https://github.com/apple/swift-metrics", from: "2.7.0"),
            .package(url: "https://github.com/jpsim/Yams", "5.4.0"..<"7.0.0"),
    ],
    targets: [
        .target(
            name: "AppRemoteConfig",
            dependencies: [
                .product(name: "Crypto", package: "swift-crypto"),
                .product(name: "Logging", package: "swift-log")
            ]
        ),
        .testTarget(
            name: "AppRemoteConfigTests",
            dependencies: [
                "AppRemoteConfig"
            ]
        ),
        .target(
            name: "AppRemoteConfigProvider",
            dependencies: [
                "AppRemoteConfig",
                .product(name: "Configuration", package: "swift-configuration"),
                .product(name: "Logging", package: "swift-log"),
                .product(
                    name: "Metrics",
                    package: "swift-metrics",
                 
                ),
                .product(name: "ServiceLifecycle", package: "swift-service-lifecycle")
            ]
        ),
        .testTarget(
            name: "AppRemoteConfigProviderTests",
            dependencies: [
                "AppRemoteConfigProvider"
            ]
        ),
        .target(
            name: "AppRemoteConfigService",
            dependencies: [
                "AppRemoteConfig",
                .product(name: "Dependencies", package: "swift-dependencies"),
            ]
        ),
        .testTarget(
            name: "AppRemoteConfigServiceTests",
            dependencies: [
                "AppRemoteConfigService"
            ]
        ),
        .target(
            name: "AppRemoteConfigServiceMacros",
            dependencies: [
                "AppRemoteConfigServiceMacrosPlugin",
                .product(name: "IssueReporting", package: "xctest-dynamic-overlay"),
            ]
        ),
        .macro(
            name: "AppRemoteConfigServiceMacrosPlugin",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
            ]
        ),
        .testTarget(
            name: "AppRemoteConfigMacrosPluginTests",
            dependencies: [
                "AppRemoteConfigServiceMacrosPlugin",
                .product(name: "MacroTesting", package: "swift-macro-testing"),
            ]
        ),
        .executableTarget(
            name: "care",
            dependencies: [
                "AppRemoteConfig",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Yams", package: "Yams")
            ]
        )
    ]
)
