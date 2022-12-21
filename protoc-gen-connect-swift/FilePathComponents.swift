/// Used to split a file path into its specific components.
struct FilePathComponents {
    /// Example: "/foo/bar" from a "/foo/bar/baz.proto" file path.
    let directory: String
    /// Example: "baz" from a "/foo/bar/baz.proto" file path.
    let base: String
    /// Example: ".proto" from a "/foo/bar/baz.proto" file path.
    let suffix: String

    /// Parse the path components from a file path.
    ///
    /// - parameter path: For example, "/foo/bar/baz.proto" or "foo/bar/baz.proto".
    init(path: String) {
        let allComponents = path.components(separatedBy: "/")
        let fileNameComponents = allComponents.last!.split(separator: ".")
        self.directory = allComponents.dropLast().joined(separator: "/")
        self.base = fileNameComponents.dropLast().joined(separator: ".")
        self.suffix = fileNameComponents.count > 1 ? "." + fileNameComponents.last! : ""
    }

    func outputFilePath(
        withExtension pathExtension: String,
        using option: GeneratorOptions.FileNaming
    ) -> String {
        switch option {
        case .dropPath:
            return "\(self.base)\(pathExtension)"

        case .fullPath:
            return "\(self.directory)\(self.base)\(pathExtension)"

        case .pathToUnderscores:
            let underscoredDirectory = self.directory.replacingOccurrences(of: "/", with: "_")
            return "\(underscoredDirectory)\(self.base)\(pathExtension)"
        }
    }
}
