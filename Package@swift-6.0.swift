// swift-tools-version: 6.0

import CompilerPluginSupport
import Foundation
import PackageDescription

let package = Package(
    name: "AppRemoteConfig",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v14),
        .macOS(.v11),
        .tvOS(.v14),
        .watchOS(.v7)
    ],
    products: [
        .library(
            name: "AppRemoteConfig",
            targets: ["AppRemoteConfig"]
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
        .package(url: "https://github.com/apple/swift-crypto.git", "1.0.0" ..< "4.0.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.0.0"),
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.0.6"),
        .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.0.0"),
        .package(url: "https://github.com/pointfreeco/swift-macro-testing", from: "0.6.0"),
        .package(url: "https://github.com/pointfreeco/xctest-dynamic-overlay", from: "1.0.0"),
        .package(url: "https://github.com/swiftlang/swift-syntax", "509.0.0"..<"602.0.0"),
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

// MARK: - Parse build arguments

func hasEnvironmentVariable(_ name: String) -> Bool {
  return ProcessInfo.processInfo.environment[name] != nil
}

var excludeService: Bool { hasEnvironmentVariable("EXCLUDE_SERVICE") }
var excludeMacros: Bool { hasEnvironmentVariable("EXCLUDE_MACROS") }

if excludeService {
    package.targets.removeAll(where: { $0.name.contains("Service") })
    package.products.removeAll(where: { $0.name.contains("Service") })
}

if excludeMacros {
    package.targets.removeAll(where: { $0.name.contains("Macros") })
    package.products.removeAll(where: { $0.name.contains("Macros") })
}
