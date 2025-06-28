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

/// Responsible for generating mocks that are compatible with generated Connect services.
@main
final class ConnectMockGenerator: Generator {
    private var propertyVisibility = ""
    private var typeVisibility = ""

    override var outputFileExtension: String {
        return ".mock.swift"
    }

    override func printContent(for descriptor: FileDescriptor) {
        super.printContent(for: descriptor)

        switch self.options.visibility {
        case .internal:
            self.propertyVisibility = "internal"
            self.typeVisibility = "internal"
        case .public:
            self.propertyVisibility = "public"
            self.typeVisibility = "open"
        case .package:
            self.propertyVisibility = "package"
            self.typeVisibility = "package"
        }

        if self.options.generateCallbackMethods {
            self.printModuleImports(adding: ["Combine", "ConnectMocks"])
        } else {
            self.printModuleImports(adding: ["ConnectMocks"])
        }

        for service in self.services {
            self.printLine()
            self.printMockService(service)
        }
    }

    private func printMockService(_ service: ServiceDescriptor) {
        let protocolName = service.protocolName(using: self.namer)
        self.printLine("/// Mock implementation of `\(protocolName)`.")
        self.printLine("///")
        self.printLine("/// Production implementations can be substituted with instances of this")
        self.printLine("/// class to mock RPC calls. Behavior can be customized")
        self.printLine("/// either through the properties on this class or by")
        self.printLine("/// subclassing the mock and overriding its methods.")
        self.printLine("///")
        self.printLine("/// Note: This class does not handle thread-safe locking, but provides")
        self.printLine("/// `@unchecked Sendable` conformance to simplify testing and mocking.")
        self.printLine("@available(iOS 13, *)")
        self.printLine(
            """
            \(self.typeVisibility) class \(service.mockName(using: self.namer)): \
            \(protocolName), @unchecked Sendable {
            """
        )
        self.indent {
            if self.options.generateCallbackMethods {
                self.printLine("private var cancellables = [Combine.AnyCancellable]()")
                self.printLine()
            }

            for method in service.methods {
                if self.options.generateCallbackMethods {
                    self.printLine(
                        "/// Mocked for calls to `\(method.name(using: self.options))()`."
                    )
                    self.printLine(
                        """
                        \(self.propertyVisibility) var \(method.callbackMockPropertyName()) = \
                        \(method.callbackMockPropertyValue(using: self.namer))
                        """
                    )
                }
                if self.options.generateAsyncMethods {
                    self.printLine(
                        "/// Mocked for async calls to `\(method.name(using: self.options))()`."
                    )
                    self.printLine(
                        """
                        \(self.propertyVisibility) var \(method.asyncAwaitMockPropertyName()) = \
                        \(method.asyncAwaitMockPropertyValue(using: self.namer))
                        """
                    )
                }
            }

            self.printLine()
            self.printLine("\(self.propertyVisibility) init() {}")

            for method in service.methods {
                if self.options.generateCallbackMethods {
                    self.printCallbackMethodMockImplementation(for: method)
                }
                if self.options.generateAsyncMethods {
                    self.printAsyncAwaitMethodMockImplementation(for: method)
                }
            }
        }

        self.printLine("}")
    }

    private func printCallbackMethodMockImplementation(for method: MethodDescriptor) {
        self.printLine()
        if let availabilityAnnotation = method.callbackAvailabilityAnnotation() {
            self.printLine(availabilityAnnotation)
        }
        if !method.serverStreaming && !method.clientStreaming {
            self.printLine("@discardableResult")
        }

        self.printLine(
            "\(self.typeVisibility) "
            + method.callbackSignature(
                using: self.namer, includeDefaults: true, options: self.options
            )
            + " {"
        )
        self.indent {
            let mockProperty = method.callbackMockPropertyName()
            if method.clientStreaming || method.serverStreaming {
                self.printLine(
                    """
                    self.\(mockProperty).$inputs\
                    .first { !$0.isEmpty }\
                    .sink { _ in self.\(mockProperty).outputs.forEach(onResult) }\
                    .store(in: &self.cancellables)
                    """
                )
                self.printLine("return self.\(mockProperty)")
            } else {
                self.printLine("completion(self.\(mockProperty)(request))")
                self.printLine("return Connect.Cancelable {}")
            }
        }
        self.printLine("}")
    }

    private func printAsyncAwaitMethodMockImplementation(for method: MethodDescriptor) {
        self.printLine()
        if let availabilityAnnotation = method.asyncAwaitAvailabilityAnnotation() {
            self.printLine(availabilityAnnotation)
        }
        self.printLine(
            "\(self.typeVisibility) "
            + method.asyncAwaitSignature(
                using: self.namer, includeDefaults: true, options: self.options
            )
            + " {"
        )
        self.indent {
            if method.clientStreaming || method.serverStreaming {
                self.printLine("return self.\(method.asyncAwaitMockPropertyName())")
            } else {
                self.printLine("return self.\(method.asyncAwaitMockPropertyName())(request)")
            }
        }
        self.printLine("}")
    }
}

private extension ServiceDescriptor {
    func mockName(using namer: SwiftProtobufNamer) -> String {
        return self.implementationName(using: namer) + "Mock"
    }
}

private extension MethodDescriptor {
    func callbackMockPropertyName() -> String {
        return "mock" + NamingUtils.toUpperCamelCase(self.name)
    }

    func asyncAwaitMockPropertyName() -> String {
        return "mockAsync" + NamingUtils.toUpperCamelCase(self.name)
    }

    func callbackMockPropertyValue(using namer: SwiftProtobufNamer) -> String {
        let inputName = namer.fullName(message: self.inputType)
        let outputName = namer.fullName(message: self.outputType)
        if self.clientStreaming && self.serverStreaming {
            return "MockBidirectionalStream<\(inputName), \(outputName)>()"
        } else if self.serverStreaming {
            return "MockServerOnlyStream<\(inputName), \(outputName)>()"
        } else if self.clientStreaming {
            return "MockClientOnlyStream<\(inputName), \(outputName)>()"
        } else {
            return """
            { (_: \(inputName)) -> ResponseMessage<\(outputName)> in \
            .init(result: .success(.init())) \
            }
            """
        }
    }

    func asyncAwaitMockPropertyValue(using namer: SwiftProtobufNamer) -> String {
        let inputName = namer.fullName(message: self.inputType)
        let outputName = namer.fullName(message: self.outputType)
        if self.clientStreaming && self.serverStreaming {
            return "MockBidirectionalAsyncStream<\(inputName), \(outputName)>()"
        } else if self.serverStreaming {
            return "MockServerOnlyAsyncStream<\(inputName), \(outputName)>()"
        } else if self.clientStreaming {
            return "MockClientOnlyAsyncStream<\(inputName), \(outputName)>()"
        } else {
            return """
            { (_: \(inputName)) -> ResponseMessage<\(outputName)> in \
            .init(result: .success(.init())) \
            }
            """
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

    func asyncAwaitAvailabilityAnnotation() -> String? {
        if self.options.deprecated {
            // swiftlint:disable:next line_length
            return "@available(iOS, introduced: 13, deprecated: 13, message: \"This RPC has been marked as deprecated in its `.proto` file.\")"
        } else {
            return nil
        }
    }
}
