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
    struct TestCase: Sendable {
        let path: String
        let expectedDirectory: String
        let expectedBase: String
        let expectedSuffix: String
        let expectedFullPathOutput: String
        let expectedDropPathOutput: String
        let expectedPathToUnderscoresOutput: String
    }

    static let testCases: [TestCase] = [
        TestCase(
            path: "/foo/bar/baz.proto",
            expectedDirectory: "/foo/bar",
            expectedBase: "baz",
            expectedSuffix: ".proto",
            expectedFullPathOutput: "/foo/bar/baz.connect.swift",
            expectedDropPathOutput: "baz.connect.swift",
            expectedPathToUnderscoresOutput: "foo_bar_baz.connect.swift"
        ),
        TestCase(
            path: "foo/bar/baz.proto",
            expectedDirectory: "foo/bar",
            expectedBase: "baz",
            expectedSuffix: ".proto",
            expectedFullPathOutput: "foo/bar/baz.connect.swift",
            expectedDropPathOutput: "baz.connect.swift",
            expectedPathToUnderscoresOutput: "foo_bar_baz.connect.swift"
        ),
        TestCase(
            path: "baz.proto",
            expectedDirectory: "",
            expectedBase: "baz",
            expectedSuffix: ".proto",
            expectedFullPathOutput: "baz.connect.swift",
            expectedDropPathOutput: "baz.connect.swift",
            expectedPathToUnderscoresOutput: "baz.connect.swift"
        ),
        TestCase(
            path: "/baz.proto",
            expectedDirectory: "",
            expectedBase: "baz",
            expectedSuffix: ".proto",
            expectedFullPathOutput: "baz.connect.swift",
            expectedDropPathOutput: "baz.connect.swift",
            expectedPathToUnderscoresOutput: "baz.connect.swift"
        ),
    ]

    @available(iOS 13, *)
    @Test(arguments: Self.testCases)
    func splitsProtoFilePath(testCase: TestCase) {
        let components = FilePathComponents(path: testCase.path)
        #expect(components.directory == testCase.expectedDirectory)
        #expect(components.base == testCase.expectedBase)
        #expect(components.suffix == testCase.expectedSuffix)
        #expect(
            components.outputFilePath(withExtension: ".connect.swift", using: .fullPath)
            == testCase.expectedFullPathOutput
        )
        #expect(
            components.outputFilePath(withExtension: ".connect.swift", using: .dropPath)
            == testCase.expectedDropPathOutput
        )
        #expect(
            components.outputFilePath(withExtension: ".connect.swift", using: .pathToUnderscores)
            == testCase.expectedPathToUnderscoresOutput
        )
    }
}

@available(iOS 13, *)
extension FilePathComponentsTests.TestCase: CustomTestStringConvertible {
    var testDescription: String {
        self.path
    }
}
