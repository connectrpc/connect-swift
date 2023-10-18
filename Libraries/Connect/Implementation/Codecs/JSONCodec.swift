// Copyright 2022-2023 The Connect Authors
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
// TODO: Remove `@preconcurrency` once `SwiftProtobuf.JSON{Encoding|Decoding}Options` are `Sendable`
@preconcurrency import SwiftProtobuf

/// Codec providing functionality for serializing to/from JSON.
public struct JSONCodec: Sendable {
    private let encodingOptions: JSONEncodingOptions
    private let decodingOptions: JSONDecodingOptions = {
        var options = JSONDecodingOptions()
        options.ignoreUnknownFields = true
        return options
    }()

    /// Designated initializer.
    ///
    /// - parameter alwaysEncodeEnumsAsInts: Always encode enums as ints. By default they are
    ///                                      encoded as strings.
    /// - parameter preserveProtobufFieldNames: Whether to preserve Protobuf field names as they're
    ///                                         defined in the `.proto` files. By default they are
    ///                                         converted to Protobuf's JSON lowerCamelCase format.
    public init(alwaysEncodeEnumsAsInts: Bool = false, preserveProtobufFieldNames: Bool = false) {
        var encodingOptions = JSONEncodingOptions()
        encodingOptions.alwaysPrintEnumsAsInts = alwaysEncodeEnumsAsInts
        encodingOptions.preserveProtoFieldNames = preserveProtobufFieldNames
        self.encodingOptions = encodingOptions
    }
}

extension JSONCodec: Codec {
    public func name() -> String {
        return "json"
    }

    public func serialize<Input: ProtobufMessage>(message: Input) throws -> Data {
        return try message.jsonUTF8Data(options: self.encodingOptions)
    }

    public func serializeDeterministically<Input: ProtobufMessage>(message: Input) throws -> Data {
        #warning("Replace with deterministic invocation")
        return try message.jsonUTF8Data(options: self.encodingOptions)
    }

    public func deserialize<Output: ProtobufMessage>(source: Data) throws -> Output {
        return try Output(jsonUTF8Data: source, options: self.decodingOptions)
    }
}
