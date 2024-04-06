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
import XCTest

final class ConnectEndStreamResponseTests: XCTestCase {
    func testLowercasesAllHeaderKeys() throws {
        let dictionary = [
            "metadata": [
                "sOmEkEy": ["foo"],
                "otherKey1": ["BAR", "bAz"],
            ],
        ]
        let data = try JSONSerialization.data(withJSONObject: dictionary)
        let response = try JSONDecoder().decode(ConnectEndStreamResponse.self, from: data)
        XCTAssertNil(response.error)
        XCTAssertEqual(response.metadata, ["somekey": ["foo"], "otherkey1": ["BAR", "bAz"]])
    }

    func testAllowsOmittedErrorAndMetadata() throws {
        let data = try JSONSerialization.data(withJSONObject: [String: Any]())
        let response = try JSONDecoder().decode(ConnectEndStreamResponse.self, from: data)
        XCTAssertNil(response.error)
        XCTAssertNil(response.metadata)
    }

    func testDeserializesError() throws {
        let dictionary = [
            "error": [
                "code": "permission_denied",
            ],
        ]
        let data = try JSONSerialization.data(withJSONObject: dictionary)
        let response = try JSONDecoder().decode(ConnectEndStreamResponse.self, from: data)
        XCTAssertEqual(response.error?.code, .permissionDenied)
    }
}
