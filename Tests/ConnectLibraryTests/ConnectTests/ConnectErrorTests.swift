// Copyright 2022-2023 Buf Technologies, Inc.
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
        let expectedDetails = Connectrpc_Conformance_V1_SimpleResponse.with {
            $0.hostname = "foobar"
        }
        let errorData = try self.errorData(expectedDetails: [expectedDetails])
        let error = try JSONDecoder().decode(ConnectError.self, from: errorData)
        XCTAssertEqual(error.code, .unavailable)
        XCTAssertEqual(error.message, "overloaded: back off and retry")
        XCTAssertNil(error.exception)
        XCTAssertEqual(error.details.count, 1)
        XCTAssertEqual(error.unpackedDetails(), [expectedDetails])
        XCTAssertTrue(error.metadata.isEmpty)
    }

    func testDeserializingFullErrorAndUnpackingMultipleDetails() throws {
        let expectedDetails1 = Connectrpc_Conformance_V1_SimpleResponse.with { $0.hostname = "foo" }
        let expectedDetails2 = Connectrpc_Conformance_V1_SimpleResponse.with { $0.hostname = "bar" }
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
        let expectedDetails = Connectrpc_Conformance_V1_SimpleResponse.with {
            $0.hostname = "foobar"
        }
        let errorData = try self.errorData(expectedDetails: [expectedDetails])
        let error = ConnectError.from(
            code: .aborted,
            headers: [
                "sOmEkEy": ["foo"],
                "otherKey1": ["BAR", "bAz"],
            ],
            source: errorData
        )
        XCTAssertEqual(error.code, .unavailable) // Respects the code from the error body
        XCTAssertEqual(error.message, "overloaded: back off and retry")
        XCTAssertNil(error.exception)
        XCTAssertEqual(error.details.count, 1)
        XCTAssertEqual(error.unpackedDetails(), [expectedDetails])
        XCTAssertEqual(error.metadata, ["somekey": ["foo"], "otherkey1": ["BAR", "bAz"]])
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
        XCTAssertEqual(error.unpackedDetails(), [Connectrpc_Conformance_V1_SimpleResponse]())
        XCTAssertTrue(error.metadata.isEmpty)
    }

    func testDeserializingEmptyDictionaryFails() throws {
        let errorData = try JSONSerialization.data(withJSONObject: [String: Any]())
        XCTAssertThrowsError(try JSONDecoder().decode(ConnectError.self, from: errorData))
    }

    // MARK: - Private

    private func errorData(expectedDetails: [ProtobufMessage]) throws -> Data {
        // Example error from https://connectrpc.com/docs/protocol/#error-end-stream
        let dictionary: [String: Any] = [
            "code": "unavailable",
            "message": "overloaded: back off and retry",
            "details": try expectedDetails.map { detail in
                [
                    "type": type(of: detail).protoMessageName,
                    "value": try detail.serializedData().base64EncodedString(),
                    "debug": ["retryDelay": "30s"],
                ] as [String: Any]
            },
        ]
        return try JSONSerialization.data(withJSONObject: dictionary)
    }
}
