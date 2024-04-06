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
import SwiftProtobuf

/// Defines a type that is capable of encoding and decoding messages using a specific format.
public protocol Codec: Sendable {
    /// - returns: The name of the codec's format (e.g., "json", "protobuf"). Usually consumed
    ///            in the form of adding the `content-type` header via "application/{name}".
    func name() -> String

    /// Serializes the input message into the codec's format.
    ///
    /// - parameter message: Typed input message.
    ///
    /// - returns: Serialized data that can be transmitted.
    func serialize<Input: ProtobufMessage>(message: Input) throws -> Data

    /// Determininstically serializes the input message into the codec's format.
    /// Invocations of this function using the same version of the library with the same message
    /// are guranteed to produce identical outputs. This is less efficient than
    /// nondeterministic serialization, as it may result in performing sorts on map fields.
    ///
    /// Note that the deterministic serialization is NOT canonical across languages.
    /// It is NOT guaranteed to remain stable over time. It is unstable across
    /// different builds with schema changes due to unknown fields. Users who need
    /// canonical serialization (e.g., persistent storage in a canonical form,
    /// fingerprinting, etc.) should define their own canonicalization specification
    /// and implement their own serializer rather than relying on this API.
    ///
    /// - parameter message: Typed input message.
    ///
    /// - returns: Serialized data that can be transmitted.
    func deterministicallySerialize<Input: ProtobufMessage>(message: Input) throws -> Data

    /// Deserializes data in the codec's format into a typed message.
    ///
    /// - parameter source: The source data to deserialize.
    ///
    /// - returns: The typed output message.
    func deserialize<Output: ProtobufMessage>(source: Data) throws -> Output
}
