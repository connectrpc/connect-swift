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

import Foundation
import SwiftProtobufPluginLibrary

private enum CommandLineParameter: String {
    case extraModuleImports = "ExtraModuleImports"
    case fileNaming = "FileNaming"
    case generateAsyncMethods = "GenerateAsyncMethods"
    case generateAsyncMocks = "GenerateAsyncMocks"
    case generateCallbackMethods = "GenerateCallbackMethods"
    case generateCallbackMocks = "GenerateCallbackMocks"
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

/// A set of options that are used to customize generator outputs.
struct GeneratorOptions {
    private(set) var extraModuleImports = [String]()
    private(set) var fileNaming = FileNaming.fullPath
    private(set) var generateAsyncMethods = true
    private(set) var generateAsyncMocks = false
    private(set) var generateCallbackMethods = true
    private(set) var generateCallbackMocks = false
    private(set) var keepMethodCasing = false
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

            case .generateAsyncMethods:
                if let value = Bool(rawValue) {
                    self.generateAsyncMethods = value
                    continue
                }

            case .generateAsyncMocks:
                if let value = Bool(rawValue) {
                    self.generateAsyncMocks = value
                    continue
                }

            case .generateCallbackMethods:
                if let value = Bool(rawValue) {
                    self.generateCallbackMethods = value
                    continue
                }

            case .generateCallbackMocks:
                if let value = Bool(rawValue) {
                    self.generateCallbackMocks = value
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
