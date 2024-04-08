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

import Connect
import Foundation
import SwiftProtobuf
import XCTest

final class JSONCodecTests: XCTestCase {
    private let message: Connectrpc_Conformance_V1_RawHTTPRequest = .with { proto in
        proto.body = .unary(Connectrpc_Conformance_V1_MessageContents.with { message in
            message.binary = Data([0x0, 0x1, 0x2, 0x3])
            message.compression = .gzip
        })
        proto.uri = "foo/bar"
        proto.headers = [
            .with { header in
                header.name = "x-header"
                header.value = ["a"]
            },
        ]
        proto.rawQueryParams = [.init()]
    }

    func testSerializingAndDeserializingWithDefaultOptions() throws {
        let codec = JSONCodec()
        let serialized = try codec.serialize(message: self.message)
        XCTAssertEqual(try codec.deserialize(source: serialized), self.message)
    }

    func testSerializingAndDeserializingWithEnumsAsInts() throws {
        let codec = JSONCodec(alwaysEncodeEnumsAsInts: true, preserveProtobufFieldNames: false)
        let serialized = try codec.serialize(message: self.message)
        let dictionary = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: serialized) as? [String: Any]
        )
        XCTAssertEqual((dictionary["unary"] as? [String: Any])?["compression"] as? Int, 2)
        XCTAssertEqual(try codec.deserialize(source: serialized), self.message)
    }

    func testSerializingAndDeserializingWithEnumsAsStrings() throws {
        let codec = JSONCodec(alwaysEncodeEnumsAsInts: false, preserveProtobufFieldNames: false)
        let serialized = try codec.serialize(message: self.message)
        let dictionary = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: serialized) as? [String: Any]
        )
        XCTAssertEqual(
            (dictionary["unary"] as? [String: Any])?["compression"] as? String, "COMPRESSION_GZIP"
        )
        XCTAssertEqual(try codec.deserialize(source: serialized), self.message)
    }

    func testSerializingAndDeserializingWithProtobufFieldNames() throws {
        let codec = JSONCodec(alwaysEncodeEnumsAsInts: false, preserveProtobufFieldNames: true)
        let serialized = try codec.serialize(message: self.message)
        let dictionary = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: serialized) as? [String: Any]
        )
        XCTAssertTrue(Set(dictionary.keys).isSuperset(of: [
            "headers",
            "unary",
            "uri",
            "raw_query_params",
        ]))
        XCTAssertEqual(try codec.deserialize(source: serialized), self.message)
    }

    func testSerializingAndDeserializingWithCamelCaseFieldNames() throws {
        let codec = JSONCodec(alwaysEncodeEnumsAsInts: false, preserveProtobufFieldNames: false)
        let serialized = try codec.serialize(message: self.message)
        let dictionary = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: serialized) as? [String: Any]
        )
        XCTAssertTrue(Set(dictionary.keys).isSuperset(of: [
            "headers",
            "unary",
            "uri",
            "rawQueryParams",
        ]))
        XCTAssertEqual(try codec.deserialize(source: serialized), self.message)
    }
}
