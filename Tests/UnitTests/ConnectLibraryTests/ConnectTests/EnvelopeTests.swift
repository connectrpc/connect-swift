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

@testable import Connect
import Foundation
import Testing

struct EnvelopeTests {
    @Test("Envelope correctly packs messages with compression and unpacks them back to original data")
    func packingAndUnpackingCompressedMessage() throws {
        let originalData = Data(repeating: 0xa, count: 50)
        let packed = Envelope._packMessage(
            originalData, using: .init(minBytes: 10, pool: GzipCompressionPool())
        )
        let compressed = try GzipCompressionPool().compress(data: originalData)
        #expect(packed[0] == 1) // Compression flag = true
        #expect(Envelope._isCompressed(packed))
        #expect(Envelope._messageLength(forPackedData: packed) == compressed.count)
        #expect(packed[5...] == compressed) // Post-prefix data should match compressed value

        let unpacked = try Envelope._unpackMessage(packed, compressionPool: GzipCompressionPool())
        #expect(unpacked.unpacked == originalData)
        #expect(unpacked.headerByte == 1) // Compression flag = true
    }

    @Test("Envelope packs messages without compression when compression configuration is nil")
    func packingAndUnpackingUncompressedMessageBecauseCompressionMinBytesIsNil() throws {
        let originalData = Data(repeating: 0xa, count: 50)
        let packed = Envelope._packMessage(originalData, using: nil)
        #expect(packed[0] == 0) // Compression flag = false
        #expect(!Envelope._isCompressed(packed))
        #expect(Envelope._messageLength(forPackedData: packed) == originalData.count)
        #expect(packed[5...] == originalData) // Post-prefix data should match compressed value

        // Compression pool should be ignored since the message is not compressed
        let unpacked = try Envelope._unpackMessage(packed, compressionPool: GzipCompressionPool())
        #expect(unpacked.unpacked == originalData)
        #expect(unpacked.headerByte == 0) // Compression flag = false
    }

    @Test("Envelope skips compression when message size is below minimum compression threshold")
    func packingAndUnpackingUncompressedMessageBecauseMessageIsTooSmall() throws {
        let originalData = Data(repeating: 0xa, count: 50)
        let packed = Envelope._packMessage(
            originalData, using: .init(minBytes: 100, pool: GzipCompressionPool())
        )
        #expect(packed[0] == 0) // Compression flag = false
        #expect(!Envelope._isCompressed(packed))
        #expect(Envelope._messageLength(forPackedData: packed) == originalData.count)
        #expect(packed[5...] == originalData) // Post-prefix data should match compressed value

        // Compression pool should be ignored since the message is not compressed
        let unpacked = try Envelope._unpackMessage(packed, compressionPool: GzipCompressionPool())
        #expect(unpacked.unpacked == originalData)
        #expect(unpacked.headerByte == 0) // Compression flag = false
    }

    @Test("Envelope throws error when trying to unpack compressed message without providing decompression pool")
    func throwsWhenUnpackingCompressedMessageWithoutDecompressionPool() throws {
        let originalData = Data(repeating: 0xa, count: 50)
        let packed = Envelope._packMessage(
            originalData, using: .init(minBytes: 10, pool: GzipCompressionPool())
        )
        let compressed = try GzipCompressionPool().compress(data: originalData)
        #expect(packed[0] == 1) // Compression flag = true
        #expect(Envelope._isCompressed(packed))
        #expect(Envelope._messageLength(forPackedData: packed) == compressed.count)
        #expect(packed[5...] == compressed) // Post-prefix data should match compressed value

        #expect(throws: Envelope.Error.missingExpectedCompressionPool) {
            try Envelope._unpackMessage(packed, compressionPool: nil)
        }
    }

    @Test("Envelope returns -1 for message length when data is too short to contain valid 5-byte header")
    func messageLengthOfIncompleteData() {
        // Messages are incomplete if they do not contain enough data for the 5-byte prefix
        for length in 0..<5 {
            let data = Data(repeating: 0xa, count: length)
            #expect(Envelope._messageLength(forPackedData: data) == -1)
        }
    }
}
