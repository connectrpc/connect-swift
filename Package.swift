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
        .iOS(.v14),
        .macOS(.v10_15),
    ],
    products: [
        // Primary Connect runtime that is depended on by generated classes.
        .library(
            name: "Connect",
            targets: ["Connect"]
        ),
        // Mock types that are imported by generated mock classes and can be used for testing.
        .library(
            name: "ConnectMocks",
            targets: ["ConnectMocks"]
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
                "buf.gen.yaml",
                "buf.work.yaml",
                "proto",
            ]
        ),
        .target(
            name: "ConnectMocks",
            dependencies: [
                .target(name: "Connect"),
                .product(name: "SwiftProtobuf", package: "swift-protobuf"),
            ],
            path: "ConnectMocks",
            exclude: [
                "README.md",
            ]
        ),
        .testTarget(
            name: "ConnectTests",
            dependencies: [
                "Connect",
                "ConnectMocks",
                .product(name: "SwiftProtobuf", package: "swift-protobuf"),
            ],
            path: "ConnectTests",
            exclude: [
                "buf.gen.yaml",
                "buf.work.yaml",
                "proto",
            ],
            resources: [
                .copy("Resources"),
            ]
        ),
        .executableTarget(
            name: "protoc-gen-connect-swift",
            dependencies: [
                .product(name: "SwiftProtobufPluginLibrary", package: "swift-protobuf"),
            ],
            path: "protoc-gen-connect-swift"
        ),
        .testTarget(
            name: "protoc-gen-connect-swift-tests",
            dependencies: [
                "protoc-gen-connect-swift",
            ],
            path: "protoc-gen-connect-swift-tests"
        ),
    ],
    swiftLanguageVersions: [.v5]
)
