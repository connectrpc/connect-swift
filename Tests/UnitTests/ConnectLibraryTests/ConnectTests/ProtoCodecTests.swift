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
import SwiftProtobuf
import XCTest

final class ProtoCodecTests: XCTestCase {
    private let message: Connectrpc_Conformance_V1_RawHTTPRequest = .with { proto in
        proto.body = .unary(Connectrpc_Conformance_V1_MessageContents.with { message in
            message.binary = Data([0x0, 0x1, 0x2, 0x3])
        })
        proto.uri = "foo/bar"
        proto.headers = [
            .with { header in
                header.name = "x-header"
                header.value = ["a"]
            },
        ]
    }

    func testSerializingAndDeserializing() throws {
        let codec = ProtoCodec()
        let serialized = try codec.serialize(message: self.message)
        XCTAssertEqual(try codec.deserialize(source: serialized), self.message)
    }
}
