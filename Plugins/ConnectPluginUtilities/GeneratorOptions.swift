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

import Foundation
import SwiftProtobufPluginLibrary

private enum CommandLineParameter: String {
    case extraModuleImports = "ExtraModuleImports"
    case fileNaming = "FileNaming"
    case generateAsyncMethods = "GenerateAsyncMethods"
    case generateCallbackMethods = "GenerateCallbackMethods"
    case generateServiceMetadata = "GenerateServiceMetadata"
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
}

/// A set of options that are used to customize generator outputs.
public struct GeneratorOptions {
    public private(set) var extraModuleImports = [String]()
    public private(set) var fileNaming = FileNaming.fullPath
    public private(set) var generateAsyncMethods = true
    public private(set) var generateCallbackMethods = false
    public private(set) var generateServiceMetadata = true
    public private(set) var keepMethodCasing = false
    public private(set) var protoToModuleMappings = ProtoFileToModuleMappings()
    public private(set) var swiftProtobufModuleName = "SwiftProtobuf"
    public private(set) var visibility = Visibility.internal

    public enum FileNaming: String {
        case fullPath = "FullPath"
        case pathToUnderscores = "PathToUnderscores"
        case dropPath = "DropPath"
    }

    public enum Visibility: String {
        case `internal` = "Internal"
        case `public` = "Public"
    }

    static func empty() -> Self {
        return .init()
    }
}

extension GeneratorOptions {
    /// Initializes a set of generator options from command line
    /// parameters (e.g., "Visibility=Internal,KeepMethodCasing=true").
    ///
    /// - parameter commandLineParameters: The CLI parameters.
    public init(commandLineParameters: SwiftProtobufPluginLibrary.CodeGeneratorParameter) throws {
        for (key, rawValue) in commandLineParameters.parsedPairs {
            guard let parsedParameter = CommandLineParameter(rawValue: key) else {
                throw CommandLineParameter.Error.unknownParameter(string: key)
            }

            switch parsedParameter {
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

            case .generateCallbackMethods:
                if let value = Bool(rawValue) {
                    self.generateCallbackMethods = value
                    continue
                }

            case .generateServiceMetadata:
                if let value = Bool(rawValue) {
                    self.generateServiceMetadata = value
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
                    throw CommandLineParameter.Error.deserializationError(key: key, error: error)
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

            throw CommandLineParameter.Error.invalidParameterValue(key: key, value: rawValue)
        }
    }
}
