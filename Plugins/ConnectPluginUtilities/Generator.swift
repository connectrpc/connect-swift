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

import SwiftProtobuf
import SwiftProtobufPluginLibrary

private struct GeneratorError: Swift.Error {
    let message: String
}

/// Base generator class that can be used to generate Swift files from Protobuf file descriptors.
/// Not intended to be instantiated directly.
/// Subclasses must be annotated with `@main` to be properly invoked at runtime.
open class Generator {
    private var neededModules = [String]()
    private var printer = SwiftProtobufPluginLibrary.CodePrinter()

    // MARK: - Overridable

    /// File extension to use for generated file names (e.g., ".connect.swift").
    /// Must be overridden by subclasses.
    open var outputFileExtension: String {
        fatalError("\(#function) must be overridden by subclasses")
    }

    /// Initializer required by `SwiftProtobufPluginLibrary.CodeGenerator`.
    public required init() {}

    /// Should be overridden by subclasses to write output for a given file descriptor.
    /// Subclasses should call `super` before producing their own outputs.
    /// May be called multiple times (once per file descriptor) over the lifetime of this class.
    ///
    /// - parameter descriptor: The file descriptor for which to generate code.
    open func printContent(for descriptor: SwiftProtobufPluginLibrary.FileDescriptor) {
        self.printLine("// Code generated by protoc-gen-connect-swift. DO NOT EDIT.")
        self.printLine("//")
        self.printLine("// Source: \(descriptor.name)")
        self.printLine("//")
        self.printLine()
    }

    // MARK: - Output helpers

    /// Used for producing type names when generating code.
    public private(set) var namer = SwiftProtobufPluginLibrary.SwiftProtobufNamer()
    /// Options to use when generating code.
    public private(set) var options = GeneratorOptions.empty()
    /// List of services specified in the current file.
    public private(set) var services = [SwiftProtobufPluginLibrary.ServiceDescriptor]()

    public func indent() {
        self.printer.indent()
    }

    public func outdent() {
        self.printer.outdent()
    }

    public func indent(printLines: () -> Void) {
        self.indent()
        printLines()
        self.outdent()
    }

    public func printLine(_ line: String = "") {
        if !line.isEmpty {
            self.printer.print(line)
        }
        self.printer.print("\n")
    }

    public func printCommentsIfNeeded(
        for entity: SwiftProtobufPluginLibrary.ProvidesSourceCodeLocation
    ) {
        let comments = entity.protoSourceComments().trimmingCharacters(in: .whitespacesAndNewlines)
        if !comments.isEmpty {
            self.printLine(comments)
        }
    }

    public func printModuleImports(adding additional: [String] = []) {
        let defaults = ["Connect", "Foundation", self.options.swiftProtobufModuleName]
        let extraOptionImports = self.options.extraModuleImports
        let allImports = (defaults + self.neededModules + extraOptionImports + additional).sorted()
        for module in allImports {
            self.printLine("import \(module)")
        }
    }
}

extension Generator: SwiftProtobufPluginLibrary.CodeGenerator {
    private func resetAndPrintFile(
        for descriptor: SwiftProtobufPluginLibrary.FileDescriptor
    ) -> String {
        self.namer = SwiftProtobufPluginLibrary.SwiftProtobufNamer(
            currentFile: descriptor,
            protoFileToModuleMappings: self.options.protoToModuleMappings
        )
        self.neededModules = self.options.protoToModuleMappings
            .neededModules(forFile: descriptor) ?? []
        self.services = descriptor.services
        self.printer = SwiftProtobufPluginLibrary.CodePrinter(indent: "    ".unicodeScalars)
        self.printContent(for: descriptor)
        return self.printer.content
    }

    public func generate(
        files: [SwiftProtobufPluginLibrary.FileDescriptor],
        parameter: any SwiftProtobufPluginLibrary.CodeGeneratorParameter,
        protoCompilerContext _: any SwiftProtobufPluginLibrary.ProtoCompilerContext,
        generatorOutputs: any SwiftProtobufPluginLibrary.GeneratorOutputs
    ) throws {
        self.options = try GeneratorOptions(commandLineParameters: parameter)
        guard self.options.generateAsyncMethods || self.options.generateCallbackMethods else {
            throw GeneratorError(
                message: "Either async methods or callback methods must be enabled"
            )
        }

        for descriptor in files where !descriptor.services.isEmpty {
            try generatorOutputs.add(
                fileName: FilePathComponents(path: descriptor.name).outputFilePath(
                    withExtension: self.outputFileExtension,
                    using: self.options.fileNaming
                ),
                contents: self.resetAndPrintFile(for: descriptor)
            )
        }
    }

    public var supportedEditionRange: ClosedRange<SwiftProtobuf.Google_Protobuf_Edition> {
        let minEdition = max(
            DescriptorSet.bundledEditionsSupport.lowerBound, Google_Protobuf_Edition.legacy
        )
        let maxEdition = min(
            DescriptorSet.bundledEditionsSupport.upperBound, Google_Protobuf_Edition.edition2023
        )
        return minEdition...maxEdition
    }

    public var supportedFeatures: [
        SwiftProtobufPluginLibrary.Google_Protobuf_Compiler_CodeGeneratorResponse.Feature
    ] {
        return [
            .proto3Optional,
            .supportsEditions,
        ]
    }
}
