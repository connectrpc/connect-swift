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
import Foundation
import SwiftProtobuf
import XCTest

final class ConnectErrorTests: XCTestCase {
    func testDeserializingFullErrorAndUnpackingDetails() throws {
        let expectedDetails = Connectrpc_Conformance_V1_RawHTTPRequest.with { $0.uri = "foo/bar" }
        let errorData = try self.errorData(expectedDetails: [expectedDetails])
        let error = try JSONDecoder().decode(ConnectError.self, from: errorData)
        XCTAssertEqual(error.code, .unavailable)
        XCTAssertEqual(error.message, "overloaded: back off and retry")
        XCTAssertNil(error.exception)
        XCTAssertEqual(error.details.count, 1)
        XCTAssertEqual(error.unpackedDetails(), [expectedDetails])
        XCTAssertTrue(error.metadata.isEmpty)
    }

    func testDeserializingFullErrorAndUnpackingDetailsWithUnpaddedBase64() throws {
        let expectedDetails = Connectrpc_Conformance_V1_RawHTTPRequest.with { $0.uri = "foo/bar" }
        let errorData = try self.errorData(expectedDetails: [expectedDetails], pad: false)
        let error = try JSONDecoder().decode(ConnectError.self, from: errorData)
        XCTAssertEqual(error.code, .unavailable)
        XCTAssertEqual(error.message, "overloaded: back off and retry")
        XCTAssertNil(error.exception)
        XCTAssertEqual(error.details.count, 1)
        XCTAssertEqual(error.unpackedDetails(), [expectedDetails])
        XCTAssertTrue(error.metadata.isEmpty)
    }

    func testDeserializingFullErrorAndUnpackingMultipleDetails() throws {
        let expectedDetails1 = Connectrpc_Conformance_V1_RawHTTPRequest.with { $0.uri = "foo/bar" }
        let expectedDetails2 = Connectrpc_Conformance_V1_RawHTTPRequest.with { $0.uri = "bar/baz" }
        let errorData = try self.errorData(expectedDetails: [expectedDetails1, expectedDetails2])
        let error = try JSONDecoder().decode(ConnectError.self, from: errorData)
        XCTAssertEqual(error.code, .unavailable)
        XCTAssertEqual(error.message, "overloaded: back off and retry")
        XCTAssertNil(error.exception)
        XCTAssertEqual(error.details.count, 2)
        XCTAssertEqual(error.unpackedDetails(), [expectedDetails1, expectedDetails2])
        XCTAssertTrue(error.metadata.isEmpty)
    }

    func testDeserializingErrorUsingHelperFunctionLowercasesHeaderKeys() throws {
        let expectedDetails = Connectrpc_Conformance_V1_RawHTTPRequest.with { $0.uri = "a/b/c" }
        let errorData = try self.errorData(expectedDetails: [expectedDetails])
        let error = ConnectError.from(
            code: .aborted,
            headers: [
                "sOmEkEy": ["foo"],
                "otherKey1": ["BAR", "bAz"],
            ],
            trailers: nil,
            source: errorData
        )
        XCTAssertEqual(error.code, .unavailable) // Respects the code from the error body
        XCTAssertEqual(error.message, "overloaded: back off and retry")
        XCTAssertNil(error.exception)
        XCTAssertEqual(error.details.count, 1)
        XCTAssertEqual(error.unpackedDetails(), [expectedDetails])
        XCTAssertEqual(error.metadata, ["somekey": ["foo"], "otherkey1": ["BAR", "bAz"]])
    }

    func testDeserializingErrorUsingHelperFunctionCombinesHeadersAndTrailers() throws {
        let expectedDetails = Connectrpc_Conformance_V1_RawHTTPRequest.with { $0.uri = "a/b/c" }
        let errorData = try self.errorData(expectedDetails: [expectedDetails])
        let error = ConnectError.from(
            code: .aborted,
            headers: [
                "duPlIcaTedKey": ["headers"],
                "otherKey1": ["BAR", "bAz"],
            ],
            trailers: [
                "duPlIcaTedKey": ["trailers"],
                "anOthErKey": ["foo"],
            ],
            source: errorData
        )
        XCTAssertEqual(error.code, .unavailable) // Respects the code from the error body
        XCTAssertEqual(error.message, "overloaded: back off and retry")
        XCTAssertNil(error.exception)
        XCTAssertEqual(error.details.count, 1)
        XCTAssertEqual(error.unpackedDetails(), [expectedDetails])
        XCTAssertEqual(error.metadata, [
            "duplicatedkey": ["trailers"],
            "otherkey1": ["BAR", "bAz"],
            "anotherkey": ["foo"],
        ])
    }

    func testDeserializingSimpleError() throws {
        let errorDictionary = [
            "code": "unavailable",
        ]
        let errorData = try JSONSerialization.data(withJSONObject: errorDictionary)
        let error = try JSONDecoder().decode(ConnectError.self, from: errorData)
        XCTAssertEqual(error.code, .unavailable)
        XCTAssertNil(error.message)
        XCTAssertNil(error.exception)
        XCTAssertTrue(error.details.isEmpty)
        XCTAssertEqual(error.unpackedDetails(), [Connectrpc_Conformance_V1_RawHTTPRequest]())
        XCTAssertTrue(error.metadata.isEmpty)
    }

    // MARK: - Private

    private func errorData(expectedDetails: [ProtobufMessage], pad: Bool = true) throws -> Data {
        // Example error from https://connectrpc.com/docs/protocol/#error-end-stream
        let dictionary: [String: Any] = [
            "code": "unavailable",
            "message": "overloaded: back off and retry",
            "details": try expectedDetails.map { detail in
                var value = try detail.serializedData().base64EncodedString()
                // If pad is false, remove all the padding added by the base64EncodedString function
                if !pad {
                    value = value.replacingOccurrences(of: "=", with: "")
                }
                return [
                    "type": type(of: detail).protoMessageName,
                    "value": value,
                    "debug": ["retryDelay": "30s"],
                ] as [String: Any]
            },
        ]
        return try JSONSerialization.data(withJSONObject: dictionary)
    }
}
