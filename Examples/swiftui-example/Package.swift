// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "SwiftUIExample",
    platforms: [
        .iOS(.v18),
        .macOS(.v15)
    ],
    products: [
        .executable(name: "SwiftUIExample", targets: ["SwiftUIExample"])
    ],
    dependencies: [
        .package(path: "../.."),
        .package(url: "https://github.com/apple/swift-configuration.git", from: "1.0.0")
    ],
    targets: [
        .executableTarget(
            name: "SwiftUIExample",
            dependencies: [
                .product(name: "AppRemoteConfigProvider", package: "app-remote-config"),
                .product(name: "AppRemoteConfig", package: "app-remote-config"),
                .product(name: "Configuration", package: "swift-configuration")
            ],
            exclude: [
                "Resources/Info.plist"
            ]
        )
    ]
)
