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

@testable import Connect
import XCTest

final class EnvelopeTests: XCTestCase {
    func testPackingAndUnpackingCompressedMessage() throws {
        let originalData = Data(repeating: 0xa, count: 50)
        let packed = Envelope.packMessage(
            originalData, using: .init(minBytes: 10, pool: GzipCompressionPool())
        )
        let compressed = try GzipCompressionPool().compress(data: originalData)
        XCTAssertEqual(packed[0], 1) // Compression flag = true
        XCTAssertEqual(Envelope.messageLength(forPackedData: packed), compressed.count)
        XCTAssertEqual(packed[5...], compressed) // Post-prefix data should match compressed value

        let unpacked = try Envelope.unpackMessage(packed, compressionPool: GzipCompressionPool())
        XCTAssertEqual(unpacked.unpacked, originalData)
        XCTAssertEqual(unpacked.headerByte, 1) // Compression flag = true
    }

    func testPackingAndUnpackingUncompressedMessageBecauseCompressionMinBytesIsNil() throws {
        let originalData = Data(repeating: 0xa, count: 50)
        let packed = Envelope.packMessage(originalData, using: nil)
        XCTAssertEqual(packed[0], 0) // Compression flag = false
        XCTAssertEqual(Envelope.messageLength(forPackedData: packed), originalData.count)
        XCTAssertEqual(packed[5...], originalData) // Post-prefix data should match compressed value

        // Compression pool should be ignored since the message is not compressed
        let unpacked = try Envelope.unpackMessage(packed, compressionPool: GzipCompressionPool())
        XCTAssertEqual(unpacked.unpacked, originalData)
        XCTAssertEqual(unpacked.headerByte, 0) // Compression flag = false
    }

    func testPackingAndUnpackingUncompressedMessageBecauseMessageIsTooSmall() throws {
        let originalData = Data(repeating: 0xa, count: 50)
        let packed = Envelope.packMessage(
            originalData, using: .init(minBytes: 100, pool: GzipCompressionPool())
        )
        XCTAssertEqual(packed[0], 0) // Compression flag = false
        XCTAssertEqual(Envelope.messageLength(forPackedData: packed), originalData.count)
        XCTAssertEqual(packed[5...], originalData) // Post-prefix data should match compressed value

        // Compression pool should be ignored since the message is not compressed
        let unpacked = try Envelope.unpackMessage(packed, compressionPool: GzipCompressionPool())
        XCTAssertEqual(unpacked.unpacked, originalData)
        XCTAssertEqual(unpacked.headerByte, 0) // Compression flag = false
    }

    func testThrowsWhenUnpackingCompressedMessageWithoutDecompressionPool() throws {
        let originalData = Data(repeating: 0xa, count: 50)
        let packed = Envelope.packMessage(
            originalData, using: .init(minBytes: 10, pool: GzipCompressionPool())
        )
        let compressed = try GzipCompressionPool().compress(data: originalData)
        XCTAssertEqual(packed[0], 1) // Compression flag = true
        XCTAssertEqual(Envelope.messageLength(forPackedData: packed), compressed.count)
        XCTAssertEqual(packed[5...], compressed) // Post-prefix data should match compressed value

        XCTAssertThrowsError(try Envelope.unpackMessage(packed, compressionPool: nil)) { error in
            XCTAssertEqual(error as? Envelope.Error, .missingExpectedCompressionPool)
        }
    }

    func testMessageLengthOfIncompleteData() {
        // Messages are incomplete if they do not contain enough data for the 5-byte prefix
        for length in 0..<5 {
            let data = Data(repeating: 0xa, count: length)
            XCTAssertEqual(Envelope.messageLength(forPackedData: data), -1)
        }
    }
}
