import Foundation
import SwiftProtobufPluginLibrary

private enum CommandLineParameter: String {
    case extraModuleImports = "ExtraModuleImports"
    case fileNaming = "FileNaming"
    case keepMethodCasing = "KeepMethodCasing"
    case protoPathModuleMappings = "ProtoPathModuleMappings"
    case swiftProtobufModuleName = "SwiftProtobufModuleName"
    case visibility = "Visibility"

    enum Error: Swift.Error {
        case deserializationError(key: String, error: Swift.Error)
        case invalidParameterValue(key: String, value: String)
        case unknownParameter(string: String)

        var localizedDescription: String {
            switch self {
            case .deserializationError(let key, let error):
                return "Parameter '\(key)' failed with error: \(error.localizedDescription)"
            case .invalidParameterValue(let key, let value):
                return "Invalid parameter value '\(value)' for '\(key)'"
            case .unknownParameter(let string):
                return "Unknown parameter '\(string)'"
            }
        }
    }

    static func parse(commandLineParameters: String) throws -> [(key: Self, value: String)] {
        return try commandLineParameters
            .components(separatedBy: ",")
            .compactMap { parameter in
                guard let index = parameter.firstIndex(of: "=") else {
                    throw Error.unknownParameter(string: parameter)
                }

                let rawKey = parameter[..<index].trimmingCharacters(in: .whitespacesAndNewlines)
                guard let key = Self(rawValue: rawKey) else {
                    throw Error.unknownParameter(string: parameter)
                }

                let value = parameter[parameter.index(after: index)...]
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if value.isEmpty {
                    return nil
                }

                return (key, value)
            }
    }
}

struct GeneratorOptions {
    private(set) var extraModuleImports = [String]()
    private(set) var keepMethodCasing = false
    private(set) var fileNaming = FileNaming.fullPath
    private(set) var protoToModuleMappings = ProtoFileToModuleMappings()
    private(set) var swiftProtobufModuleName = "SwiftProtobuf"
    private(set) var visibility = Visibility.internal

    enum FileNaming: String {
        case fullPath = "FullPath"
        case pathToUnderscores = "PathToUnderscores"
        case dropPath = "DropPath"
    }

    enum Visibility: String {
        case `internal` = "Internal"
        case `public` = "Public"
    }

    /// Initializes a set of generator options from the raw string representation of command line
    /// parameters (e.g., "Visibility=Internal,KeepMethodCasing=true").
    ///
    /// Handles trimming whitespace, and some parameters may be specified multiple times.
    ///
    /// - parameter commandLineParameters: The raw CLI parameters.
    init(commandLineParameters: String) throws {
        let parsedParameters = try CommandLineParameter.parse(
            commandLineParameters: commandLineParameters
        )
        for (key, rawValue) in parsedParameters {
            switch key {
            case .extraModuleImports:
                self.extraModuleImports.append(rawValue)
                continue

            case .fileNaming:
                if let value = FileNaming(rawValue: rawValue) {
                    self.fileNaming = value
                    continue
                }

            case .keepMethodCasing:
                if let value = Bool(rawValue) {
                    self.keepMethodCasing = value
                    continue
                }

            case .protoPathModuleMappings:
                do {
                    self.protoToModuleMappings = try ProtoFileToModuleMappings(path: rawValue)
                    continue
                } catch let error {
                    throw CommandLineParameter.Error.deserializationError(
                        key: key.rawValue, error: error
                    )
                }

            case .swiftProtobufModuleName:
                self.swiftProtobufModuleName = rawValue
                continue

            case .visibility:
                if let value = Visibility(rawValue: rawValue) {
                    self.visibility = value
                    continue
                }
            }

            throw CommandLineParameter.Error.invalidParameterValue(
                key: key.rawValue,
                value: rawValue
            )
        }
    }
}
