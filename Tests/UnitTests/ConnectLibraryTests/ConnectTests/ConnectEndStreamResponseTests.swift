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

struct ConnectEndStreamResponseTests {
    @Test("ConnectEndStreamResponse normalizes metadata header keys to lowercase during deserialization")
    func lowercasesAllHeaderKeys() throws {
        let dictionary = [
            "metadata": [
                "sOmEkEy": ["foo"],
                "otherKey1": ["BAR", "bAz"],
            ],
        ]
        let data = try JSONSerialization.data(withJSONObject: dictionary)
        let response = try JSONDecoder().decode(ConnectEndStreamResponse.self, from: data)
        #expect(response.error == nil)
        #expect(response.metadata == ["somekey": ["foo"], "otherkey1": ["BAR", "bAz"]])
    }

    @Test("ConnectEndStreamResponse handles empty JSON with optional error and metadata fields")
    func allowsOmittedErrorAndMetadata() throws {
        let data = try JSONSerialization.data(withJSONObject: [String: Any]())
        let response = try JSONDecoder().decode(ConnectEndStreamResponse.self, from: data)
        #expect(response.error == nil)
        #expect(response.metadata == nil)
    }

    @Test("ConnectEndStreamResponse correctly deserializes embedded ConnectError from JSON")
    func deserializesError() throws {
        let dictionary = [
            "error": [
                "code": "permission_denied",
            ],
        ]
        let data = try JSONSerialization.data(withJSONObject: dictionary)
        let response = try JSONDecoder().decode(ConnectEndStreamResponse.self, from: data)
        #expect(response.error?.code == .permissionDenied)
    }
}
