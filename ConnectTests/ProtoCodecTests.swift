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
import Generated
import SwiftProtobuf
import XCTest

final class ProtoCodecTests: XCTestCase {
    private let message: Grpc_Testing_SimpleResponse = .with { proto in
        proto.grpclbRouteType = .backend
        proto.payload = .with { payload in payload.body = Data([0x0, 0x1, 0x2, 0x3]) }
        proto.serverID = "12345"
        proto.username = "foo"
    }

    func testSerializingAndDeserializing() throws {
        let codec = ProtoCodec()
        let serialized = try codec.serialize(message: self.message)
        XCTAssertEqual(try codec.deserialize(source: serialized), self.message)
    }
}
