// Copyright 2022-2024 The Connect Authors
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

@testable import ConnectPluginUtilities
import Foundation
import XCTest

final class FilePathComponentsTests: XCTestCase {
    func testProtoFilePathWithLeadingSlash() {
        let components = FilePathComponents(path: "/foo/bar/baz.proto")
        XCTAssertEqual(components.directory, "/foo/bar")
        XCTAssertEqual(components.base, "baz")
        XCTAssertEqual(components.suffix, ".proto")
        XCTAssertEqual(
            components.outputFilePath(withExtension: ".connect.swift", using: .fullPath),
            "/foo/bar/baz.connect.swift"
        )
        XCTAssertEqual(
            components.outputFilePath(withExtension: ".connect.swift", using: .dropPath),
            "baz.connect.swift"
        )
        XCTAssertEqual(
            components.outputFilePath(withExtension: ".connect.swift", using: .pathToUnderscores),
            "foo_bar_baz.connect.swift"
        )
    }

    func testProtoFilePathWithoutLeadingSlash() {
        let components = FilePathComponents(path: "foo/bar/baz.proto")
        XCTAssertEqual(components.directory, "foo/bar")
        XCTAssertEqual(components.base, "baz")
        XCTAssertEqual(components.suffix, ".proto")
        XCTAssertEqual(
            components.outputFilePath(withExtension: ".connect.swift", using: .fullPath),
            "foo/bar/baz.connect.swift"
        )
        XCTAssertEqual(
            components.outputFilePath(withExtension: ".connect.swift", using: .dropPath),
            "baz.connect.swift"
        )
        XCTAssertEqual(
            components.outputFilePath(withExtension: ".connect.swift", using: .pathToUnderscores),
            "foo_bar_baz.connect.swift"
        )
    }

    func testProtoFilePathWithoutDirectoryOrLeadingSlash() {
        let components = FilePathComponents(path: "baz.proto")
        XCTAssertEqual(components.directory, "")
        XCTAssertEqual(components.base, "baz")
        XCTAssertEqual(components.suffix, ".proto")
        XCTAssertEqual(
            components.outputFilePath(withExtension: ".connect.swift", using: .fullPath),
            "baz.connect.swift"
        )
        XCTAssertEqual(
            components.outputFilePath(withExtension: ".connect.swift", using: .dropPath),
            "baz.connect.swift"
        )
        XCTAssertEqual(
            components.outputFilePath(withExtension: ".connect.swift", using: .pathToUnderscores),
            "baz.connect.swift"
        )
    }

    func testProtoFilePathWithoutDirectoryButWithLeadingSlash() {
        let components = FilePathComponents(path: "/baz.proto")
        XCTAssertEqual(components.directory, "")
        XCTAssertEqual(components.base, "baz")
        XCTAssertEqual(components.suffix, ".proto")
        XCTAssertEqual(
            components.outputFilePath(withExtension: ".connect.swift", using: .fullPath),
            "baz.connect.swift"
        )
        XCTAssertEqual(
            components.outputFilePath(withExtension: ".connect.swift", using: .dropPath),
            "baz.connect.swift"
        )
        XCTAssertEqual(
            components.outputFilePath(withExtension: ".connect.swift", using: .pathToUnderscores),
            "baz.connect.swift"
        )
    }
}
