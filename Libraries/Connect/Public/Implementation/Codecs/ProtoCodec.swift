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
// TODO: Remove `@preconcurrency` once `SwiftProtobuf.BinaryEncodingOptions` is `Sendable`
@preconcurrency import SwiftProtobuf

/// Codec providing functionality for serializing to/from Protobuf binary.
public struct ProtoCodec {
    private let deterministicEncodingOptions: BinaryEncodingOptions = {
        var encodingOptions = BinaryEncodingOptions()
        encodingOptions.useDeterministicOrdering = true
        return encodingOptions
    }()

    public init() {}
}

extension ProtoCodec: Codec {
    public func name() -> String {
        return "proto"
    }

    public func serialize<Input: ProtobufMessage>(message: Input) throws -> Data {
        return try message.serializedData()
    }

    public func deterministicallySerialize<Input: ProtobufMessage>(message: Input) throws -> Data {
        return try message.serializedData(options: self.deterministicEncodingOptions)
    }

    public func deserialize<Output: ProtobufMessage>(source: Data) throws -> Output {
        return try Output(serializedData: source)
    }
}
