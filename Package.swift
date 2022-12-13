// swift-tools-version:5.6

import PackageDescription

let package = Package(
    name: "Connect",
    platforms: [
        .iOS(.v14),
        .macOS(.v10_14),
    ],
    products: [
        .library(
            name: "Connect",
            targets: ["Connect"]
        ),
        .library(
            name: "SwiftGenerated",
            targets: ["SwiftGenerated"]
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
                "SwiftGenerated",
                .product(name: "SwiftProtobuf", package: "swift-protobuf"),
            ],
            path: "crosstests"
        ),
        .target(
            name: "SwiftGenerated",
            dependencies: [
                "Connect",
                .product(name: "SwiftProtobuf", package: "swift-protobuf"),
            ],
            path: "gen"
        ),
    ],
    swiftLanguageVersions: [.v5]
)
