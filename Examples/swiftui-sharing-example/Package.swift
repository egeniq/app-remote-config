// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "SwiftUISharingExample",
    platforms: [
        .iOS(.v17),
        .macOS(.v15)
    ],
    products: [
        .executable(name: "SwiftUISharingExample", targets: ["SwiftUISharingExample"])
    ],
    dependencies: [
        .package(path: "../.."),
        .package(path: "../../../swift-configuration-sharing"),
        .package(url: "https://github.com/apple/swift-configuration.git", from: "1.0.0"),
        .package(url: "https://github.com/pointfreeco/swift-sharing", from: "2.7.4")
    ],
    targets: [
        .executableTarget(
            name: "SwiftUISharingExample",
            dependencies: [
                .product(name: "AppRemoteConfigProvider", package: "app-remote-config"),
                .product(name: "AppRemoteConfig", package: "app-remote-config"),
                .product(name: "ConfigurationSharing", package: "ConfigurationSharing"),
                .product(name: "Configuration", package: "swift-configuration"),
                .product(name: "Sharing", package: "swift-sharing")
            ],
            exclude: [
                "Resources/Info.plist"
            ]
        )
    ]
)
