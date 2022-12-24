// swift-tools-version:5.6

import PackageDescription

let package = Package(
    name: "Connect",
    platforms: [
        .iOS(.v14),
        .macOS(.v10_15),
    ],
    products: [
        // Primary library for consumers to use.
        .library(
            name: "Connect",
            targets: ["Connect"]
        ),
        // Library used by example apps within this repository.
        .library(
            name: "Generated",
            targets: ["Generated"]
        ),
        // Generator executable for Connect RPCs.
        .executable(
            name: "protoc-gen-connect-swift",
            targets: ["protoc-gen-connect-swift"]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/apple/swift-protobuf.git",
            from: "1.20.3"
        ),
    ],
    targets: [
        .target(
            name: "Connect",
            dependencies: [
                .product(name: "SwiftProtobuf", package: "swift-protobuf"),
            ],
            path: "Connect",
            exclude: [
                "proto",
            ]
        ),
        .testTarget(
            name: "ConnectTests",
            dependencies: [
                "Connect",
                "Generated",
                .product(name: "SwiftProtobuf", package: "swift-protobuf"),
            ],
            path: "ConnectTests",
            exclude: [
                "proto",
            ]
        ),
        .target(
            name: "Generated",
            dependencies: [
                "Connect",
                .product(name: "SwiftProtobuf", package: "swift-protobuf"),
            ],
            path: "Generated"
        ),
        .executableTarget(
            name: "protoc-gen-connect-swift",
            dependencies: [
                .product(name: "SwiftProtobufPluginLibrary", package: "swift-protobuf"),
            ],
            path: "protoc-gen-connect-swift"
        ),
    ],
    swiftLanguageVersions: [.v5]
)
