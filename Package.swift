// swift-tools-version:5.6

// Copyright 2022-2023 Buf Technologies, Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import PackageDescription

let package = Package(
    name: "Connect",
    platforms: [
        .iOS(.v12),
        .macOS(.v10_15),
        .tvOS(.v13),
        .watchOS(.v6)
    ],
    products: [
        .library(
            name: "Connect",
            targets: ["Connect"]
        ),
        .library(
            name: "ConnectMocks",
            targets: ["ConnectMocks"]
        ),
        .library(
            name: "ConnectNIO",
            targets: ["ConnectNIO"]
        ),
        .executable(
            name: "protoc-gen-connect-swift",
            targets: ["ConnectSwiftPlugin"]
        ),
        .executable(
            name: "protoc-gen-connect-swift-mocks",
            targets: ["ConnectMocksPlugin"]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/apple/swift-nio.git",
            from: "2.63.0"
        ),
        .package(
            url: "https://github.com/apple/swift-nio-http2.git",
            from: "1.30.0"
        ),
        .package(
            url: "https://github.com/apple/swift-nio-ssl.git",
            from: "2.26.0"
        ),
        .package(
            url: "https://github.com/apple/swift-protobuf.git",
            from: "1.26.0"
        ),
    ],
    targets: [
        .target(
            name: "Connect",
            dependencies: [
                .product(name: "SwiftProtobuf", package: "swift-protobuf"),
            ],
            path: "Libraries/Connect",
            exclude: [
                "buf.gen.yaml",
                "proto",
                "README.md",
            ]
        ),
        .executableTarget(
            name: "ConnectConformanceClient",
            dependencies: [
                "Connect",
                "ConnectNIO",
                .product(name: "SwiftProtobuf", package: "swift-protobuf"),
            ],
            path: "Tests/ConformanceClient",
            exclude: [
                "buf.gen.yaml",
                "InvocationConfigs",
                "README.md",
            ]
        ),
        .testTarget(
            name: "ConnectLibraryTests",
            dependencies: [
                "Connect",
                "ConnectMocks",
                .product(name: "SwiftProtobuf", package: "swift-protobuf"),
            ],
            path: "Tests/UnitTests/ConnectLibraryTests",
            exclude: [
                "buf.gen.yaml",
            ],
            resources: [
                .copy("TestResources"),
            ]
        ),
        .target(
            name: "ConnectMocks",
            dependencies: [
                .target(name: "Connect"),
                .product(name: "SwiftProtobuf", package: "swift-protobuf"),
            ],
            path: "Libraries/ConnectMocks",
            exclude: [
                "README.md",
            ]
        ),
        .executableTarget(
            name: "ConnectMocksPlugin",
            dependencies: [
                "ConnectPluginUtilities",
                .product(name: "SwiftProtobufPluginLibrary", package: "swift-protobuf"),
            ],
            path: "Plugins/ConnectMocksPlugin"
        ),
        .target(
            name: "ConnectNIO",
            dependencies: [
                "Connect",
                .product(name: "NIOConcurrencyHelpers", package: "swift-nio"),
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOFoundationCompat", package: "swift-nio"),
                .product(name: "NIOHTTP1", package: "swift-nio"),
                .product(name: "NIOHTTP2", package: "swift-nio-http2"),
                .product(name: "NIOPosix", package: "swift-nio"),
                .product(name: "NIOSSL", package: "swift-nio-ssl"),
            ],
            path: "Libraries/ConnectNIO",
            exclude: [
                "README.md",
            ]
        ),
        .target(
            name: "ConnectPluginUtilities",
            dependencies: [
                .product(name: "SwiftProtobufPluginLibrary", package: "swift-protobuf"),
            ],
            path: "Plugins/ConnectPluginUtilities"
        ),
        .testTarget(
            name: "ConnectPluginUtilitiesTests",
            dependencies: [
                "ConnectPluginUtilities",
            ],
            path: "Tests/UnitTests/ConnectPluginUtilitiesTests"
        ),
        .executableTarget(
            name: "ConnectSwiftPlugin",
            dependencies: [
                "ConnectPluginUtilities",
                .product(name: "SwiftProtobufPluginLibrary", package: "swift-protobuf"),
            ],
            path: "Plugins/ConnectSwiftPlugin"
        ),
    ],
    swiftLanguageVersions: [.v5]
)
