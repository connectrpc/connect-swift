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

import Foundation
import SwiftProtobuf

/// Typed error provided by Connect RPCs that may optionally wrap additional typed custom errors
/// using `details`.
public struct ConnectError: Swift.Error, Sendable {
    /// The resulting status code.
    public let code: Code
    /// User-readable error message.
    public let message: String?
    /// Client-side exception that occurred, resulting in the error.
    public let exception: Swift.Error?
    /// List of typed errors that were provided by the server. See `unpackedDetails()`.
    public let details: [Detail]
    /// Additional key-values that were provided by the server.
    public let metadata: Headers

    /// Unpacks values from `self.details` and returns all matching errors.
    ///
    /// Any decoding errors are ignored, and the detail will simply be omitted from the list.
    ///
    /// To access only the first error of a specific type:
    /// `let unpackedError: MyError? = error.unpackedDetails().first`
    ///
    /// - returns: The matching unpacked typed error details.
    public func unpackedDetails<Output: ProtobufMessage>() -> [Output] {
        return self.details.compactMap { detail -> Output? in
            guard detail.type == Output.protoMessageName else {
                return nil
            }

            return detail.payload.flatMap { try? Output(serializedData: $0) }
        }
    }

    public init(
        code: Code, message: String?, exception: Error?, details: [Detail], metadata: Headers
    ) {
        self.code = code
        self.message = message
        self.exception = exception
        self.details = details
        self.metadata = metadata
    }

    /// Error details are sent over the network to clients, which can then work with
    /// strongly-typed data rather than trying to parse a complex error message. For
    /// example, you might use details to send a localized error message or retry
    /// parameters to the client.
    ///
    /// The `google.golang.org/genproto/googleapis/rpc/errdetails` package contains a
    /// variety of Protobuf messages commonly used as error details.
    public struct Detail: Swift.Decodable, Sendable {
        public let type: String
        public let payload: Data?

        private enum CodingKeys: String, CodingKey {
            case type = "type"
            case payload = "value"
        }

        public init(from decoder: Swift.Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let encodedPayload = try container.decodeIfPresent(String.self, forKey: .payload) ?? ""
            let paddedPayload = encodedPayload.addingBase64PaddingIfNeeded()
            self.init(
                type: try container.decodeIfPresent(String.self, forKey: .type) ?? "",
                payload: Data(base64Encoded: paddedPayload)
            )
        }

        public init(type: String, payload: Data?) {
            self.type = type
            self.payload = payload
        }
    }
}

extension ConnectError: Decodable {
    public init(from decoder: Swift.Decoder) throws {
        let decodedError = try DecodableConnectError(from: decoder)
        self.init(decodedError: decodedError, defaultCode: .unknown, metadata: [:])
    }
}

extension ConnectError {
    public static func from(
        code: Code, headers: Headers?, trailers: Trailers?, source: Data?
    ) -> Self {
        // Combine headers + trailers into metadata to make error parsing easier for consumers,
        // since gRPC can include error information in either headers or trailers.
        var metadata = Headers()
        for (headerName, headerValue) in headers ?? [:] {
            metadata[headerName.lowercased()] = headerValue
        }
        for (trailerName, trailerValue) in trailers ?? [:] {
            metadata[trailerName.lowercased()] = trailerValue
        }

        guard let source = source else {
            return .init(
                code: code, message: "empty error message from source", exception: nil,
                details: [], metadata: metadata
            )
        }

        do {
            return try ConnectError.decode(from: source, defaultCode: code, metadata: metadata)
        } catch let error {
            return .init(
                code: code, message: String(data: source, encoding: .utf8),
                exception: error, details: [], metadata: metadata
            )
        }
    }

    public static func canceled() -> Self {
        return .init(
            code: .canceled, message: "request canceled by client",
            exception: nil, details: [], metadata: [:]
        )
    }
}

// MARK: - Internal

/// Allows for decoding all fields as optionals using `Swift.Decodable`.
private struct DecodableConnectError: Decodable {
    let code: String?
    let message: String?
    let details: [ConnectError.Detail]?

    private enum CodingKeys: String, CodingKey {
        case code = "code"
        case message = "message"
        case details = "details"
    }
}

private extension ConnectError {
    init(decodedError: DecodableConnectError, defaultCode: Code, metadata: Headers) {
        self.init(
            code: decodedError.code.flatMap(Code.fromName) ?? defaultCode,
            message: decodedError.message,
            exception: nil,
            details: decodedError.details ?? [],
            metadata: metadata
        )
    }

    static func decode(from data: Data, defaultCode: Code, metadata: Headers) throws -> Self {
        let decodedError = try Foundation.JSONDecoder()
            .decode(DecodableConnectError.self, from: data)
        return .init(decodedError: decodedError, defaultCode: defaultCode, metadata: metadata)
    }
}

extension String {
    func addingBase64PaddingIfNeeded() -> Self {
        // Base64-encoded strings should be a length that is a multiple of four. If the
        // original string is not, it should be padded with "=" to guard against a
        // corrupted string.
        return self.padding(
            // Calculate the nearest multiple of 4 that is >= the length of the string,
            // then pad the string to that length.
            toLength: ((self.count + 3) / 4) * 4,
            withPad: "=",
            startingAt: 0
        )
    }
}
