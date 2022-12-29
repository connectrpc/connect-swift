// Copyright 2022 Buf Technologies, Inc.
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
import Generated
import SwiftProtobuf
import XCTest

final class JSONCodecTests: XCTestCase {
    private let message: Grpc_Testing_SimpleResponse = .with { proto in
        proto.grpclbRouteType = .backend
        proto.payload = .with { payload in payload.body = Data([0x0, 0x1, 0x2, 0x3]) }
        proto.serverID = "12345"
        proto.username = "foo"
    }

    func testSerializingAndDeserializingWithDefaultOptions() throws {
        let codec = JSONCodec()
        let serialized = try codec.serialize(message: self.message)
        XCTAssertEqual(try codec.deserialize(source: serialized), self.message)
    }

    func testSerializingAndDeserializingWithEnumsAsInts() throws {
        let codec = JSONCodec(alwaysEncodeEnumsAsInts: true, encodeProtoFieldNames: false)
        let serialized = try codec.serialize(message: self.message)
        let dictionary = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: serialized) as? [String: Any]
        )
        XCTAssertEqual(dictionary["grpclbRouteType"] as? Int, 2)
        XCTAssertEqual(try codec.deserialize(source: serialized), self.message)
    }

    func testSerializingAndDeserializingWithEnumsAsStrings() throws {
        let codec = JSONCodec(alwaysEncodeEnumsAsInts: false, encodeProtoFieldNames: false)
        let serialized = try codec.serialize(message: self.message)
        let dictionary = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: serialized) as? [String: Any]
        )
        XCTAssertEqual(dictionary["grpclbRouteType"] as? String, "GRPCLB_ROUTE_TYPE_BACKEND")
        XCTAssertEqual(try codec.deserialize(source: serialized), self.message)
    }

    func testSerializingAndDeserializingWithProtoFieldNames() throws {
        let codec = JSONCodec(alwaysEncodeEnumsAsInts: false, encodeProtoFieldNames: true)
        let serialized = try codec.serialize(message: self.message)
        let dictionary = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: serialized) as? [String: Any]
        )
        XCTAssertTrue(Set(dictionary.keys).isSuperset(of: [
            "grpclb_route_type",
            "server_id",
            "username",
        ]))
        XCTAssertEqual(try codec.deserialize(source: serialized), self.message)
    }

    func testSerializingAndDeserializingWithCamelCaseFieldNames() throws {
        let codec = JSONCodec(alwaysEncodeEnumsAsInts: false, encodeProtoFieldNames: false)
        let serialized = try codec.serialize(message: self.message)
        let dictionary = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: serialized) as? [String: Any]
        )
        XCTAssertTrue(Set(dictionary.keys).isSuperset(of: [
            "grpclbRouteType",
            "serverId",
            "username",
        ]))
        XCTAssertEqual(try codec.deserialize(source: serialized), self.message)
    }
}
