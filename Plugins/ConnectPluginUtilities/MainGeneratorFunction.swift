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

import Foundation
import SwiftProtobufPluginLibrary

private struct GeneratorError: Swift.Error {
    let message: String
}

/// Provides the implementation of a `main()` function for generating outputs at runtime
/// using standard in/out and a specific generator type.
public final class MainGeneratorFunction {
    private let generatorType: Generator.Type
    private let outputFileExtension: String

    public init(generatorType: Generator.Type, outputFileExtension: String) {
        self.generatorType = generatorType
        self.outputFileExtension = outputFileExtension
    }

    public func generateFromStandardInToStandardOut() {
        do {
            var response = Google_Protobuf_Compiler_CodeGeneratorResponse(
                files: [],
                supportedFeatures: [.proto3Optional]
            )
            let request = try Google_Protobuf_Compiler_CodeGeneratorRequest(
                serializedData: FileHandle.standardInput.readDataToEndOfFile()
            )
            let descriptors = DescriptorSet(protos: request.protoFile)
            let options = try GeneratorOptions(commandLineParameters: request.parameter)

            guard options.generateAsyncMethods || options.generateCallbackMethods else {
                throw GeneratorError(
                    message: "Either async methods or callback methods must be enabled"
                )
            }

            for name in request.fileToGenerate {
                guard let descriptor = descriptors.fileDescriptor(named: name) else {
                    continue
                }

                if descriptor.services.isEmpty {
                    continue
                }

                response.file.append(.with { outputFile in
                    outputFile.name = FilePathComponents(path: descriptor.name).outputFilePath(
                        withExtension: self.outputFileExtension, using: options.fileNaming
                    )
                    outputFile.content = self.generatorType.init(
                        descriptor, options: options
                    ).output
                })
            }
            FileHandle.standardOutput.write(try response.serializedData())
        } catch let error {
            FileHandle.standardError.write(("\(error)" + "\n").data(using: .utf8)!)
        }
    }
}
