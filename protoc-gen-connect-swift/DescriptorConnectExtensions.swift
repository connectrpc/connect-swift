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

extension ServiceDescriptor {
    func implementationName(using namer: SwiftProtobufNamer) -> String {
        let upperCamelName = NamingUtils.toUpperCamelCase(self.name) + "Client"
        if self.file.package.isEmpty {
            return upperCamelName
        } else {
            return namer.typePrefix(forFile: self.file) + upperCamelName
        }
    }

    func protocolName(using namer: SwiftProtobufNamer) -> String {
        return self.implementationName(using: namer) + "Interface"
    }
}

extension MethodDescriptor {
    var methodPath: String {
        if self.file.package.isEmpty {
            return "\(self.service.name)/\(self.name)"
        } else {
            return "\(self.file.package).\(self.service.name)/\(self.name)"
        }
    }

    func name(using options: GeneratorOptions) -> String {
        return options.keepMethodCasing
            ? self.name
            : NamingUtils.toLowerCamelCase(self.name)
    }

    func callbackSignature(
        using namer: SwiftProtobufNamer, includeDefaults: Bool, options: GeneratorOptions
    ) -> String {
        let methodName = self.name(using: options)
        let inputName = namer.fullName(message: self.inputType)
        let outputName = namer.fullName(message: self.outputType)

        // Note that the method name is escaped to avoid using Swift keywords.
        if self.clientStreaming && self.serverStreaming {
            return """
            func `\(methodName)`\
            (headers: Connect.Headers\(includeDefaults ? " = [:]" : ""), \
            onResult: @escaping (Connect.StreamResult<\(outputName)>) -> Void) \
            -> any Connect.BidirectionalStreamInterface<\(inputName)>
            """
        } else if self.serverStreaming {
            return """
            func `\(methodName)`\
            (headers: Connect.Headers\(includeDefaults ? " = [:]" : ""), \
            onResult: @escaping (Connect.StreamResult<\(outputName)>) -> Void) \
            -> any Connect.ServerOnlyStreamInterface<\(inputName)>
            """
        } else if self.clientStreaming {
            return """
            func `\(methodName)`\
            (headers: Connect.Headers\(includeDefaults ? " = [:]" : ""), \
            onResult: @escaping (Connect.StreamResult<\(outputName)>) -> Void) \
            -> any Connect.ClientOnlyStreamInterface<\(inputName)>
            """
        } else {
            return """
            func `\(methodName)`\
            (request: \(inputName), headers: Connect.Headers\(includeDefaults ? " = [:]" : ""), \
            completion: @escaping (ResponseMessage<\(outputName)>) -> Void) \
            -> Connect.Cancelable
            """
        }
    }

    func asyncAwaitSignature(
        using namer: SwiftProtobufNamer, includeDefaults: Bool, options: GeneratorOptions
    ) -> String {
        let methodName = self.name(using: options)
        let inputName = namer.fullName(message: self.inputType)
        let outputName = namer.fullName(message: self.outputType)

        // Note that the method name is escaped to avoid using Swift keywords.
        if self.clientStreaming && self.serverStreaming {
            return """
            func `\(methodName)`\
            (headers: Connect.Headers\(includeDefaults ? " = [:]" : "")) \
            -> any Connect.BidirectionalAsyncStreamInterface<\(inputName), \(outputName)>
            """
        } else if self.serverStreaming {
            return """
            func `\(methodName)`\
            (headers: Connect.Headers\(includeDefaults ? " = [:]" : "")) \
            -> any Connect.ServerOnlyAsyncStreamInterface<\(inputName), \(outputName)>
            """
        } else if self.clientStreaming {
            return """
            func `\(methodName)`\
            (headers: Connect.Headers\(includeDefaults ? " = [:]" : "")) \
            -> any Connect.ClientOnlyAsyncStreamInterface<\(inputName), \(outputName)>
            """
        } else {
            return """
            func `\(methodName)`\
            (request: \(inputName), headers: Connect.Headers\(includeDefaults ? " = [:]" : "")) \
            async -> ResponseMessage<\(outputName)>
            """
        }
    }
}
