// swift-tools-version: 6.3

import CompilerPluginSupport
import Foundation
import PackageDescription

let package = Package(
    name: "AppRemoteConfig",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),
        .tvOS(.v15),
        .watchOS(.v9)
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
    traits: [
      .trait(
        name: "Crypto",
        description: "Support for signing and verifying data"
      ),
      .trait(
        name: "IssueReporting",
        description: "Surface logical issues as unobtrusive runtime warnings"
      ),
      .trait(
        name: "Logging",
        description: "Show log messages"
      ),
      .default(enabledTraits: ["Crypto", "Logging"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-crypto.git", from: "4.0.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.0.0"),
        .package(url: "https://github.com/jpsim/Yams.git", from: "6.2.0"),
        .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.17.0"),
        .package(url: "https://github.com/pointfreeco/swift-macro-testing", from: "0.6.0"),
        .package(url: "https://github.com/pointfreeco/swift-issue-reporting", from: "2.0.0"),
        .package(url: "https://github.com/swiftlang/swift-syntax", "509.0.0"..<"605.0.0"),
    ],
    targets: [
        .target(
            name: "AppRemoteConfig",
            dependencies: [
                .product(
                    name: "Crypto",
                    package: "swift-crypto",
                    condition: .when(traits: [
                        "Crypto"
                    ])
                )
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
                .product(
                    name: "Crypto",
                    package: "swift-crypto",
                    condition: .when(traits: [
                        "Crypto"
                    ])
                ),
                .product(
                    name: "Logging",
                    package: "swift-log",
                    condition: .when(traits: [
                        "Logging"
                    ])
                ),
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
                .product(
                    name: "IssueReporting",
                    package: "swift-issue-reporting",
                    condition: .when(traits: [
                        "IssueReporting"
                    ])
                ),
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
                .product(
                    name: "Crypto",
                    package: "swift-crypto",
                    condition: .when(traits: [
                        "Crypto"
                    ])
                ),
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Yams", package: "Yams")
            ]
        )
    ],
    swiftLanguageModes: [.v6]
)

func hasEnvironmentVariable(_ name: String) -> Bool {
    ProcessInfo.processInfo.environment[name] != nil
}

// AppRemoteConfigService and the macros are not supported on Android, Linux and Windows (they need Combine/Apple frameworks).
if hasEnvironmentVariable("EXCLUDE_SERVICE") {
    package.targets.removeAll(where: { $0.name.contains("Service") })
    package.products.removeAll(where: { $0.name.contains("Service") })
}

if hasEnvironmentVariable("EXCLUDE_MACROS") {
    package.targets.removeAll(where: { $0.name.contains("Macros") })
    package.products.removeAll(where: { $0.name.contains("Macros") })
}
