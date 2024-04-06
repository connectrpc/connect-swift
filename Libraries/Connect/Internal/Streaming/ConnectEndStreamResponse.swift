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

/// Structure modeling the final JSON message that is returned by Connect streams:
/// https://connectrpc.com/docs/protocol#error-end-stream
struct ConnectEndStreamResponse: Sendable {
    /// Connect error that was returned with the response.
    let error: ConnectError?
    /// Additional metadata that was passed with the response. Keys are guaranteed to be lowercased.
    let metadata: Trailers?
}

extension ConnectEndStreamResponse: Decodable {
    private enum CodingKeys: String, CodingKey {
        case error = "error"
        case metadata = "metadata"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawMetadata = try container.decodeIfPresent(Trailers.self, forKey: .metadata)
        self.init(
            error: try container.decodeIfPresent(ConnectError.self, forKey: .error),
            metadata: rawMetadata?.reduce(into: Trailers()) { trailers, current in
                trailers[current.key.lowercased()] = current.value
            }
        )
    }
}
