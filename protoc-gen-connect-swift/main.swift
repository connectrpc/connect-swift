//
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
//

import Foundation
import SwiftProtobufPluginLibrary

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

    for name in request.fileToGenerate {
        guard let descriptor = descriptors.fileDescriptor(named: name) else {
            continue
        }

        if descriptor.services.isEmpty {
            continue
        }

        response.file.append(.with { outputFile in
            outputFile.name = FilePathComponents(path: descriptor.name)
                .outputFilePath(withExtension: ".connect.swift", using: options.fileNaming)
            outputFile.content = ConnectGenerator(descriptor, options: options).output
        })
    }
    FileHandle.standardOutput.write(try response.serializedData())
} catch let error {
    FileHandle.standardError.write(("\(error)" + "\n").data(using: .utf8)!)
}
