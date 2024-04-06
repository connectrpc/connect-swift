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

/// Used to split a file path into its specific components.
public struct FilePathComponents {
    /// Example: "/foo/bar" from a "/foo/bar/baz.proto" file path.
    let directory: String
    /// Example: "baz" from a "/foo/bar/baz.proto" file path.
    let base: String
    /// Example: ".proto" from a "/foo/bar/baz.proto" file path.
    let suffix: String

    /// Parse the path components from a file path.
    ///
    /// - parameter path: For example, "/foo/bar/baz.proto" or "foo/bar/baz.proto".
    public init(path: String) {
        let allComponents = path.components(separatedBy: "/")
        let fileNameComponents = allComponents.last!.split(separator: ".")
        self.directory = allComponents.dropLast().joined(separator: "/")
        self.base = fileNameComponents.dropLast().joined(separator: ".")
        self.suffix = fileNameComponents.count > 1 ? "." + fileNameComponents.last! : ""
    }

    public func outputFilePath(
        withExtension pathExtension: String,
        using option: GeneratorOptions.FileNaming
    ) -> String {
        if self.directory.isEmpty {
            return "\(self.base)\(pathExtension)"
        }

        switch option {
        case .dropPath:
            return "\(self.base)\(pathExtension)"

        case .fullPath:
            return "\(self.directory)/\(self.base)\(pathExtension)"

        case .pathToUnderscores:
            let underscoredDirectory = self.directory.replacingOccurrences(of: "/", with: "_")
            if underscoredDirectory.hasPrefix("_") {
                return "\(underscoredDirectory.dropFirst())_\(self.base)\(pathExtension)"
            } else {
                return "\(underscoredDirectory)_\(self.base)\(pathExtension)"
            }
        }
    }
}
