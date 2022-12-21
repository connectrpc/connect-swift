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

