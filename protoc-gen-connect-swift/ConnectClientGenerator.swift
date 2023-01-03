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

/// Responsible for generating services and RPCs that are compatible with the Connect library.
final class ConnectClientGenerator: Generator {
    private let visibility: String

    override init(_ descriptor: FileDescriptor, options: GeneratorOptions) {
        switch options.visibility {
        case .internal:
            self.visibility = "internal"
        case .public:
            self.visibility = "public"
        }
        super.init(descriptor, options: options)
    
        self.printContent()
    }

    private func printContent() {
        self.printFilePreamble()

        self.printModuleImports()

        for service in self.descriptor.services {
            self.printLine()
            self.printService(service)
        }
    }

    private func printService(_ service: ServiceDescriptor) {
        self.printCommentsIfNeeded(for: service)

        let protocolName = service.protocolName(using: self.namer)
        self.printLine("\(self.visibility) protocol \(protocolName) {")
        self.indent {
            for method in service.methods {
                if self.options.generateCallbackMethods {
                    self.printCallbackMethodInterface(for: method)
                }
                if self.options.generateAsyncMethods {
                    self.printAsyncAwaitMethodInterface(for: method)
                }
            }
        }
        self.printLine("}")

        self.printLine()

        let className = service.implementationName(using: self.namer)
        self.printLine("/// Concrete implementation of `\(protocolName)`.")
        self.printLine("\(self.visibility) final class \(className): \(protocolName) {")
        self.indent {
            self.printLine("private let client: Connect.ProtocolClientInterface")
            self.printLine()
            self.printLine("\(self.visibility) init(client: Connect.ProtocolClientInterface) {")
            self.indent {
                self.printLine("self.client = client")
            }
            self.printLine("}")

            for method in service.methods {
                if self.options.generateCallbackMethods {
                    self.printCallbackMethodImplementation(for: method)
                }
                if self.options.generateAsyncMethods {
                    self.printAsyncAwaitMethodImplementation(for: method)
                }
            }
        }
        self.printLine("}")
    }

    private func printCallbackMethodInterface(for method: MethodDescriptor) {
        self.printLine()
        self.printCommentsIfNeeded(for: method)
        if !method.serverStreaming && !method.clientStreaming {
            self.printLine("@discardableResult")
        }

        self.printLine(
            method.callbackSignature(
                using: self.namer, includeDefaults: false, options: self.options
            )
        )
    }

    private func printAsyncAwaitMethodInterface(for method: MethodDescriptor) {
        self.printLine()
        self.printCommentsIfNeeded(for: method)
        self.printLine(
            method.asyncAwaitSignature(
                using: self.namer, includeDefaults: false, options: self.options
            )
        )
    }

    private func printCallbackMethodImplementation(for method: MethodDescriptor) {
        self.printLine()
        if !method.serverStreaming && !method.clientStreaming {
            self.printLine("@discardableResult")
        }

        self.printLine(
            "\(self.visibility) "
            + method.callbackSignature(
                using: self.namer, includeDefaults: true, options: self.options
            )
            + " {"
        )
        self.indent {
            self.printLine("return \(method.callbackReturnValue())")
        }
        self.printLine("}")
    }

    private func printAsyncAwaitMethodImplementation(for method: MethodDescriptor) {
        self.printLine()
        self.printLine(
            "\(self.visibility) "
            + method.asyncAwaitSignature(
                using: self.namer, includeDefaults: true, options: self.options
            )
            + " {"
        )
        self.indent {
            self.printLine("return \(method.asyncAwaitReturnValue())")
        }
        self.printLine("}")
    }
}

private extension MethodDescriptor {
    func callbackReturnValue() -> String {
        if self.clientStreaming && self.serverStreaming {
            return """
            self.client.bidirectionalStream(\
            path: "\(self.methodPath)", headers: headers, onResult: onResult)
            """
        } else if self.serverStreaming {
            return """
            self.client.serverOnlyStream(\
            path: "\(self.methodPath)", headers: headers, onResult: onResult)
            """
        } else if self.clientStreaming {
            return """
            self.client.clientOnlyStream(\
            path: "\(self.methodPath)", headers: headers, onResult: onResult)
            """
        } else {
            return """
            self.client.unary(\
            path: "\(self.methodPath)", request: request, headers: headers, completion: completion)
            """
        }
    }

    func asyncAwaitReturnValue() -> String {
        if self.clientStreaming && self.serverStreaming {
            return """
            self.client.bidirectionalStream(path: "\(self.methodPath)", headers: headers)
            """
        } else if self.serverStreaming {
            return """
            self.client.serverOnlyStream(path: "\(self.methodPath)", headers: headers)
            """
        } else if self.clientStreaming {
            return """
            self.client.clientOnlyStream(path: "\(self.methodPath)", headers: headers)
            """
        } else {
            return """
            await self.client.unary(path: "\(self.methodPath)", request: request, headers: headers)
            """
        }
    }
}
