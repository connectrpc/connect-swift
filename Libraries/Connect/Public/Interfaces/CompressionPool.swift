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

/// Conforming types provide the functionality to compress/decompress data using a specific
/// algorithm.
///
/// `ProtocolClientInterface` implementations are expected to use the first compression pool with
/// a matching `name()` for decompressing inbound responses.
///
/// Outbound request compression can be specified using additional options that specify a
/// `compressionName` that matches a compression pool's `name()`.
public protocol CompressionPool: Sendable {
    /// The name of the compression pool, which corresponds to the `content-encoding` header.
    /// Example: `gzip`.
    ///
    /// - returns: The name of the compression pool that can be used with the `content-encoding`
    ///            header.
    func name() -> String

    /// Compress an outbound request message.
    ///
    /// - parameter data: The uncompressed request message.
    ///
    /// - returns: The compressed request message.
    func compress(data: Data) throws -> Data

    /// Decompress an inbound response message.
    ///
    /// - parameter data: The compressed response message.
    ///
    /// - returns: The uncompressed response message.
    func decompress(data: Data) throws -> Data
}
