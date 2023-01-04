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

import Foundation
import SwiftProtobuf

/// Typed error provided by Connect RPCs that may optionally wrap additional typed custom errors
/// using `details`.
public struct ConnectError: Swift.Error {
    /// The resulting status code.
    public let code: Code
    /// User-readable error message.
    public let message: String?
    /// Client-side exception that occurred, resulting in the error.
    public let exception: Swift.Error?
    /// List of typed errors that were provided by the server. See `unpackedDetails()`.
    public let details: [Detail]
    /// Additional key-values that were provided by the server.
    public private(set) var metadata: Headers

    /// Unpacks values from `self.details` and returns the first matching error, if any.
    ///
    /// - returns: The unpacked typed error details, if available.
    public func unpackedDetails<Output: SwiftProtobuf.Message>() -> Output? {
        for detail in self.details where detail.type == Output.protoMessageName {
            if let decoded = detail.payload.flatMap({ try? Output(serializedData: $0) }) {
                return decoded
            }
        }
        return nil
    }

    /// Error details are sent over the network to clients, which can then work with
    /// strongly-typed data rather than trying to parse a complex error message. For
    /// example, you might use details to send a localized error message or retry
    /// parameters to the client.
    ///
    /// The `google.golang.org/genproto/googleapis/rpc/errdetails` package contains a
    /// variety of Protobuf messages commonly used as error details.
    public struct Detail: Swift.Decodable {
        public let type: String
        public let payload: Data?

        private enum CodingKeys: String, CodingKey {
            case type = "type"
            case payload = "value"
        }
    }
}

extension ConnectError: Swift.Decodable {
    private enum CodingKeys: String, CodingKey {
        case code = "code"
        case message = "message"
        case details = "details"
    }

    public init(from decoder: Swift.Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            code: Code.fromName(try container.decode(String.self, forKey: .code)),
            message: try container.decodeIfPresent(String.self, forKey: .message),
            exception: nil,
            details: try container.decodeIfPresent([Detail].self, forKey: .details) ?? [],
            metadata: [:]
        )
    }
}

extension ConnectError {
    public static func from(code: Code, headers: Headers, source: Data?) -> Self {
        let headers = headers.reduce(into: Headers(), { headers, current in
            headers[current.key.lowercased()] = current.value
        })

        guard let source = source else {
            return ConnectError(
                code: code, message: "empty error message from source", exception: nil,
                details: [], metadata: headers
            )
        }

        do {
            var connectError = try Foundation.JSONDecoder().decode(ConnectError.self, from: source)
            connectError.metadata = headers
            return connectError
        } catch let error {
            return ConnectError(
                code: code, message: String(data: source, encoding: .utf8),
                exception: error, details: [], metadata: headers
            )
        }
    }
}
