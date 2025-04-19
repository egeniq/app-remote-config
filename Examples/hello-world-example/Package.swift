// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "hello-world-example",
    platforms: [.macOS(.v11), .iOS(.v13), .tvOS(.v13), .watchOS(.v6), .visionOS(.v1)],
    products: [
        .library(
            name: "HelloRemoteConfig",
            targets: ["HelloRemoteConfig"]
        )
        ],
    dependencies: [
        .package(path: "../..")
        
//        .package(url: "https://github.com/apple/swift-openapi-generator", from: "1.6.0"),
//        .package(url: "https://github.com/apple/swift-openapi-runtime", from: "1.7.0"),
//        .package(url: "https://github.com/apple/swift-openapi-urlsession", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "HelloRemoteConfig",
//            dependencies: [
//                .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
//                .product(name: "OpenAPIURLSession", package: "swift-openapi-urlsession"),
//            ],
            plugins: [.plugin(name: "AppRemoteConfigGenerator", package: "app-remote-config")]
        )
    ]
)
