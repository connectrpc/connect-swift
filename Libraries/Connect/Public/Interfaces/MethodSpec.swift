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

/// Contains metadata for a specific RPC method.
public struct MethodSpec: Equatable, Codable, Sendable {
    /// The name of the method (1:1 with the `.proto` file). E.g., `Foo`.
    public let name: String
    /// The fully qualified name of the method's service. E.g., `foo.v1.FooService`.
    public let service: String
    /// The type of method (unary, bidirectional stream, etc.).
    public let type: MethodType

    /// The path of the RPC, constructed using the package, service, and method name.
    /// E.g., `foo.v1.FooService/Foo`.
    public var path: String {
        return "\(self.service)/\(self.name)"
    }

    public enum MethodType: Equatable, Codable, Sendable {
        case unary
        case clientStream
        case serverStream
        case bidirectionalStream
    }

    public init(name: String, service: String, type: MethodType) {
        self.name = name
        self.service = service
        self.type = type
    }
}
