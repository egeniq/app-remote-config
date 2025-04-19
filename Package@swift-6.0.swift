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
            name: "AppRemoteConfigClient",
            targets: ["AppRemoteConfigClient"]
        ),
        
        .plugin(name: "AppRemoteConfigGenerator", targets: ["AppRemoteConfigGenerator"]),
        .plugin(name: "AppRemoteConfigGeneratorCommand", targets: ["AppRemoteConfigGeneratorCommand"]),
        
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
        .package(url: "https://github.com/pointfreeco/swift-sharing", from: "2.4.0"),
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
            name: "AppRemoteConfigClient",
            dependencies: [
                "AppRemoteConfig",
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "Sharing", package: "swift-sharing"),
            ]
        ),
        .testTarget(
            name: "AppRemoteConfigClientTests",
            dependencies: [
                "AppRemoteConfigClient"
            ]
        ),
        
        // Build Plugin
        .plugin(name: "AppRemoteConfigGenerator", capability: .buildTool(), dependencies: ["care"]),
      
        // Command Plugin
        .plugin(
            name: "AppRemoteConfigGeneratorCommand",
            capability: .command(
                intent: .custom(
                    verb: "generate-code-for-app-remote-config",
                    description: "Generate Swift code for an App Remote Config document."
                ),
                permissions: [
                    .writeToPackageDirectory(
                        reason: "To write the generated Swift files back into the source directory of the package."
                    )
                ]
            ),
            dependencies: ["care"]
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
