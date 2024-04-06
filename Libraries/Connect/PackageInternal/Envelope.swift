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

/// Provides functionality for packing and unpacking (headers and length prefixed) messages.
///
/// This should not be considered part of Connect's public/stable interface, and is subject
/// to change. When the compiler supports it, this should be package-internal.
public enum Envelope {
    /// Packs a message into an "envelope", adding required header bytes and optionally
    /// applying compression.
    ///
    /// Compliant with Connect streams: https://connectrpc.com/docs/protocol/#streaming-request
    /// And gRPC: https://github.com/grpc/grpc/blob/master/doc/PROTOCOL-HTTP2.md#requests
    ///
    /// - parameter source: The input message data.
    /// - parameter compression: Configuration to use for compressing the message.
    ///
    /// - returns: Serialized/enveloped data for transmission.
    public static func packMessage(
        _ source: Data, using compression: ProtocolClientConfig.RequestCompression?
    ) -> Data {
        var buffer = Data()
        if !source.isEmpty,
            let compression = compression,
            compression.shouldCompress(source),
            let compressedSource = try? compression.pool.compress(data: source)
        {
            buffer.append(0b00000001) // 1 byte with the compression bit active
            self.write(lengthOf: compressedSource, to: &buffer)
            buffer.append(compressedSource)
            return buffer
        } else {
            buffer.append(0) // 1 byte with no active flags
            self.write(lengthOf: source, to: &buffer)
            buffer.append(source)
            return buffer
        }
    }

    /// Unpacks a message from a Connect or gRPC "envelope" by reading header bytes and
    /// decompressing the message if needed.
    ///
    /// **Expects a fully framed envelope, not a partial message.**
    ///
    /// Compliant with Connect streams: https://connectrpc.com/docs/protocol/#streaming-response
    /// And gRPC: https://github.com/grpc/grpc/blob/master/doc/PROTOCOL-HTTP2.md#responses
    ///
    /// - parameter source: The full envelope's data (header bytes + message bytes).
    /// - parameter compressionPool: The compression pool that should be used for decompressing the
    ///                              message if it is compressed.
    ///
    /// - returns: A tuple that includes the header byte and the un-prefixed and decompressed
    ///            message.
    public static func unpackMessage(
        _ source: Data, compressionPool: CompressionPool?
    ) throws -> (headerByte: UInt8, unpacked: Data) {
        if source.isEmpty {
            return (0, source)
        }

        let headerByte = source[0]
        let isCompressed = 0b00000001 & headerByte != 0
        let messageData = Data(source.dropFirst(self.prefixLength))
        if isCompressed {
            guard let compressionPool = compressionPool else {
                throw Error.missingExpectedCompressionPool
            }
            return (headerByte, try compressionPool.decompress(data: messageData))
        } else {
            return (headerByte, messageData)
        }
    }

    // MARK: - Internal

    enum Error: Swift.Error {
        case missingExpectedCompressionPool
    }

    /// The total number of bytes that will prefix a message.
    static var prefixLength: Int {
        return 5 // Header flags (1 byte) + message length (4 bytes)
    }

    /// Computes the length of the message contained by a packed chunk of data.
    /// A packed chunk in this context refers to prefixed message data.
    ///
    /// Compliant with Connect streams: https://connectrpc.com/docs/protocol/#streaming-request
    /// And gRPC: https://github.com/grpc/grpc/blob/master/doc/PROTOCOL-HTTP2.md#responses
    ///
    /// - parameter data: The packed data from which to determine the enveloped message's size.
    ///
    /// - returns: The length of the next expected message in the packed data. If multiple chunks
    ///            are specified, this will return the length of the first. Returns -1 if there is
    ///            not enough prefix data to determine the message length.
    static func messageLength(forPackedData data: Data) -> Int {
        guard data.count >= self.prefixLength else {
            return -1
        }

        // Skip header flags (1 byte) and determine the message length (next 4 bytes, big-endian)
        var messageLength: UInt32 = 0
        (data[1...4] as NSData).getBytes(&messageLength, length: 4)
        messageLength = UInt32(bigEndian: messageLength)
        return Int(messageLength)
    }

    // MARK: - Private

    private static func write(lengthOf message: Data, to buffer: inout Data) {
        var messageLength = UInt32(message.count).bigEndian
        buffer.append(Data(bytes: &messageLength, count: MemoryLayout<UInt32>.size))
    }
}
