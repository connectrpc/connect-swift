struct FilePathComponents {
    let directory: String
    let base: String
    let suffix: String

    init(path: String) {
        let components = path.components(separatedBy: "/")
        let fileNameComponents = components.last!.split(separator: ".")
        self.directory = components.dropLast().joined(separator: "/")
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
