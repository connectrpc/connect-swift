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
            name: "GeneratedExamples",
            targets: ["GeneratedExamples"]
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
            path: "library"
        ),
        .testTarget(
            name: "ConnectTests",
            dependencies: [
                "Connect",
                "GeneratedExamples",
                .product(name: "SwiftProtobuf", package: "swift-protobuf"),
            ],
            path: "tests",
            exclude: [
                "crosstests-local.patch",
            ]
        ),
        .target(
            name: "GeneratedExamples",
            dependencies: [
                "Connect",
                .product(name: "SwiftProtobuf", package: "swift-protobuf"),
            ],
            path: "gen"
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
