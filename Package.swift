// swift-tools-version:5.6

//
// Copyright 2022 Buf Technologies, Inc.
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
//

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
            ],
            resources: [
                .copy("Resources"),
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
