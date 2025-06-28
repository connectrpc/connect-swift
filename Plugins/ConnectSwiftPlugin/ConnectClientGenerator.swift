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

import ConnectPluginUtilities
import Foundation
import SwiftProtobufPluginLibrary

/// Responsible for generating services and RPCs that are compatible with the Connect library.
@main
final class ConnectClientGenerator: Generator {
    private var visibility = ""

    override var outputFileExtension: String {
        ".connect.swift"
    }

    override func printContent(for descriptor: FileDescriptor) {
        super.printContent(for: descriptor)

        switch self.options.visibility {
        case .internal:
            self.visibility = "internal"
        case .public:
            self.visibility = "public"
        case .package:
            self.visibility = "package"
        }

        self.printModuleImports()

        for service in self.services {
            self.printLine()
            self.printService(service)
        }
    }

    private func printService(_ service: ServiceDescriptor) {
        self.printCommentsIfNeeded(for: service)

        let protocolName = service.protocolName(using: self.namer)
        self.printLine("\(self.visibility) protocol \(protocolName): Sendable {")
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
        self.printLine(
            "\(self.visibility) final class \(className): \(protocolName), Sendable {"
        )
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

            if self.options.generateServiceMetadata {
                self.printSpecs(for: service)
            }
        }
        self.printLine("}")
    }

    private func printSpecs(for service: ServiceDescriptor) {
        self.printLine()
        self.printLine("\(self.visibility) enum Metadata {")
        self.indent {
            self.printLine("\(self.visibility) enum Methods {")
            self.indent {
                for method in service.methods {
                    self.printLine(
                        """
                        \(self.visibility) static let \(method.name(using: self.options)) = \
                        Connect.MethodSpec(\
                        name: "\(method.name)", \
                        service: "\(method.service.servicePath)", \
                        type: \(method.specStreamType())\
                        )
                        """
                    )
                }
            }
            self.printLine("}")
        }
        self.printLine("}")
    }

    private func printCallbackMethodInterface(for method: MethodDescriptor) {
        self.printLine()
        self.printCommentsIfNeeded(for: method)
        if let availabilityAnnotation = method.callbackAvailabilityAnnotation() {
            self.printLine(availabilityAnnotation)
        }
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
        self.printLine(method.asyncAwaitAvailabilityAnnotation())
        self.printLine(
            method.asyncAwaitSignature(
                using: self.namer, includeDefaults: false, options: self.options
            )
        )
    }

    private func printCallbackMethodImplementation(for method: MethodDescriptor) {
        self.printLine()
        if let availabilityAnnotation = method.callbackAvailabilityAnnotation() {
            self.printLine(availabilityAnnotation)
        }
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
        self.printLine(method.asyncAwaitAvailabilityAnnotation())
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
    func specStreamType() -> String {
        if self.clientStreaming && self.serverStreaming {
            return ".bidirectionalStream"
        } else if self.serverStreaming {
            return ".serverStream"
        } else if self.clientStreaming {
            return ".clientStream"
        } else {
            return ".unary"
        }
    }

    func idempotencyLevel() -> String {
        switch self.options.idempotencyLevel {
        case .idempotencyUnknown:
            return "unknown"
        case .noSideEffects:
            return "noSideEffects"
        case .idempotent:
            return "idempotent"
        }
    }

    func callbackAvailabilityAnnotation() -> String? {
        if self.options.deprecated {
            // swiftlint:disable line_length
            return """
            @available(iOS, introduced: 12, deprecated: 12, message: "This RPC has been marked as deprecated in its `.proto` file.")
            @available(macOS, introduced: 10.15, deprecated: 10.15, message: "This RPC has been marked as deprecated in its `.proto` file.")
            @available(tvOS, introduced: 13, deprecated: 13, message: "This RPC has been marked as deprecated in its `.proto` file.")
            @available(watchOS, introduced: 6, deprecated: 6, message: "This RPC has been marked as deprecated in its `.proto` file.")
            """
            // swiftlint:enable line_length
        } else {
            return nil
        }
    }

    func asyncAwaitAvailabilityAnnotation() -> String {
        if self.options.deprecated {
            // swiftlint:disable:next line_length
            return "@available(iOS, introduced: 13, deprecated: 13, message: \"This RPC has been marked as deprecated in its `.proto` file.\")"
        } else {
            return "@available(iOS 13, *)"
        }
    }

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
            path: "\(self.methodPath)", \
            idempotencyLevel: .\(self.idempotencyLevel()), \
            request: request, \
            headers: headers, \
            completion: completion)
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
            await self.client.unary(\
            path: "\(self.methodPath)", \
            idempotencyLevel: .\(self.idempotencyLevel()), \
            request: request, \
            headers: headers)
            """
        }
    }
}
