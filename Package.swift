// swift-tools-version:5.6

import PackageDescription

let package = Package(
    name: "Connect",
    platforms: [
        .iOS(.v14),
        .macOS(.v10_14),
    ],
    products: [
        // Primary library for consumers to use
        .library(
            name: "Connect",
            targets: ["Connect"]
        ),
        // Library used by example apps within this repository
        .library(
            name: "GeneratedExamples",
            targets: ["GeneratedExamples"]
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
            path: "connect-swift/src"
        ),
        .testTarget(
            name: "ConnectCrosstests",
            dependencies: [
                "Connect",
                "GeneratedExamples",
                .product(name: "SwiftProtobuf", package: "swift-protobuf"),
            ],
            path: "crosstests"
        ),
        .target(
            name: "GeneratedExamples",
            dependencies: [
                "Connect",
                .product(name: "SwiftProtobuf", package: "swift-protobuf"),
            ],
            path: "gen"
        ),
    ],
    swiftLanguageVersions: [.v5]
)
