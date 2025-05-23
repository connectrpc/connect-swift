// Copyright 2022-2025 The Connect Authors
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
import Testing

struct FilePathComponentsTests {
    @Test func protoFilePathWithLeadingSlash() {
        let components = FilePathComponents(path: "/foo/bar/baz.proto")
        #expect(components.directory == "/foo/bar")
        #expect(components.base == "baz")
        #expect(components.suffix == ".proto")
        #expect(
            components.outputFilePath(withExtension: ".connect.swift", using: .fullPath)
            == "/foo/bar/baz.connect.swift"
        )
        #expect(
            components.outputFilePath(withExtension: ".connect.swift", using: .dropPath)
            == "baz.connect.swift"
        )
        #expect(
            components.outputFilePath(withExtension: ".connect.swift", using: .pathToUnderscores)
            == "foo_bar_baz.connect.swift"
        )
    }

    @Test func protoFilePathWithoutLeadingSlash() {
        let components = FilePathComponents(path: "foo/bar/baz.proto")
        #expect(components.directory == "foo/bar")
        #expect(components.base == "baz")
        #expect(components.suffix == ".proto")
        #expect(
            components.outputFilePath(withExtension: ".connect.swift", using: .fullPath)
            == "foo/bar/baz.connect.swift"
        )
        #expect(
            components.outputFilePath(withExtension: ".connect.swift", using: .dropPath)
            == "baz.connect.swift"
        )
        #expect(
            components.outputFilePath(withExtension: ".connect.swift", using: .pathToUnderscores)
            == "foo_bar_baz.connect.swift"
        )
    }

    @Test func protoFilePathWithoutDirectoryOrLeadingSlash() {
        let components = FilePathComponents(path: "baz.proto")
        #expect(components.directory == "")
        #expect(components.base == "baz")
        #expect(components.suffix == ".proto")
        #expect(
            components.outputFilePath(withExtension: ".connect.swift", using: .fullPath)
            == "baz.connect.swift"
        )
        #expect(
            components.outputFilePath(withExtension: ".connect.swift", using: .dropPath)
            == "baz.connect.swift"
        )
        #expect(
            components.outputFilePath(withExtension: ".connect.swift", using: .pathToUnderscores)
            == "baz.connect.swift"
        )
    }

    @Test func protoFilePathWithoutDirectoryButWithLeadingSlash() {
        let components = FilePathComponents(path: "/baz.proto")
        #expect(components.directory == "")
        #expect(components.base == "baz")
        #expect(components.suffix == ".proto")
        #expect(
            components.outputFilePath(withExtension: ".connect.swift", using: .fullPath)
            == "baz.connect.swift"
        )
        #expect(
            components.outputFilePath(withExtension: ".connect.swift", using: .dropPath)
            == "baz.connect.swift"
        )
        #expect(
            components.outputFilePath(withExtension: ".connect.swift", using: .pathToUnderscores)
            == "baz.connect.swift"
        )
    }
}
