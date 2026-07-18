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
import SwiftProtobuf
import Testing

struct ConnectErrorTests {
    @available(iOS 13, *)
    @Test
    func deserializingFullErrorAndUnpackingDetails() throws {
        let expectedDetails = Connectrpc_Conformance_V1_RawHTTPRequest.with { $0.uri = "foo/bar" }
        let errorData = try self.errorData(expectedDetails: [expectedDetails])
        let error = try JSONDecoder().decode(ConnectError.self, from: errorData)
        #expect(error.code == .unavailable)
        #expect(error.message == "overloaded: back off and retry")
        #expect(error.exception == nil)
        #expect(error.details.count == 1)
        #expect(error.unpackedDetails() == [expectedDetails])
        #expect(error.metadata.isEmpty)
    }

    @available(iOS 13, *)
    @Test
    func deserializingFullErrorAndUnpackingDetailsWithUnpaddedBase64() throws {
        let expectedDetails = Connectrpc_Conformance_V1_RawHTTPRequest.with { $0.uri = "foo/bar" }
        let errorData = try self.errorData(expectedDetails: [expectedDetails], pad: false)
        let error = try JSONDecoder().decode(ConnectError.self, from: errorData)
        #expect(error.code == .unavailable)
        #expect(error.message == "overloaded: back off and retry")
        #expect(error.exception == nil)
        #expect(error.details.count == 1)
        #expect(error.unpackedDetails() == [expectedDetails])
        #expect(error.metadata.isEmpty)
    }

    @available(iOS 13, *)
    @Test
    func deserializingFullErrorAndUnpackingMultipleDetails() throws {
        let expectedDetails1 = Connectrpc_Conformance_V1_RawHTTPRequest.with { $0.uri = "foo/bar" }
        let expectedDetails2 = Connectrpc_Conformance_V1_RawHTTPRequest.with { $0.uri = "bar/baz" }
        let errorData = try self.errorData(expectedDetails: [expectedDetails1, expectedDetails2])
        let error = try JSONDecoder().decode(ConnectError.self, from: errorData)
        #expect(error.code == .unavailable)
        #expect(error.message == "overloaded: back off and retry")
        #expect(error.exception == nil)
        #expect(error.details.count == 2)
        #expect(error.unpackedDetails() == [expectedDetails1, expectedDetails2])
        #expect(error.metadata.isEmpty)
    }

    @available(iOS 13, *)
    @Test
    func deserializingErrorUsingHelperFunctionLowercasesHeaderKeys() throws {
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
        #expect(error.code == .unavailable) // Respects the code from the error body
        #expect(error.message == "overloaded: back off and retry")
        #expect(error.exception == nil)
        #expect(error.details.count == 1)
        #expect(error.unpackedDetails() == [expectedDetails])
        #expect(error.metadata == ["somekey": ["foo"], "otherkey1": ["BAR", "bAz"]])
    }

    @available(iOS 13, *)
    @Test
    func deserializingErrorUsingHelperFunctionCombinesHeadersAndTrailers() throws {
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
        #expect(error.code == .unavailable) // Respects the code from the error body
        #expect(error.message == "overloaded: back off and retry")
        #expect(error.exception == nil)
        #expect(error.details.count == 1)
        #expect(error.unpackedDetails() == [expectedDetails])
        #expect(error.metadata == [
            "duplicatedkey": ["trailers"],
            "otherkey1": ["BAR", "bAz"],
            "anotherkey": ["foo"],
        ])
    }

    @available(iOS 13, *)
    @Test
    func deserializingSimpleError() throws {
        let errorDictionary = [
            "code": "unavailable",
        ]
        let errorData = try JSONSerialization.data(withJSONObject: errorDictionary)
        let error = try JSONDecoder().decode(ConnectError.self, from: errorData)
        #expect(error.code == .unavailable)
        #expect(error.message == nil)
        #expect(error.exception == nil)
        #expect(error.details.isEmpty)
        #expect(error.unpackedDetails() == [Connectrpc_Conformance_V1_RawHTTPRequest]())
        #expect(error.metadata.isEmpty)
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
