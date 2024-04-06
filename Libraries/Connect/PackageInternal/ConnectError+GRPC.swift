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

extension ConnectError {
    /// This should not be considered part of Connect's public/stable interface, and is subject
    /// to change. When the compiler supports it, this should be package-internal.
    ///
    /// Parses gRPC headers and/or trailers to obtain the status and any potential error.
    ///
    /// - parameter headers: Headers received from the server.
    /// - parameter trailers: Trailers received from the server. Note that this could be trailers
    ///                       passed in the headers block for gRPC-Web.
    ///
    /// - returns: A tuple containing the gRPC status code and an optional error.
    public static func parseGRPCHeaders(
        _ headers: Headers?, trailers: Trailers?
    ) -> (grpcCode: Code, error: ConnectError?) {
        // "Trailers-only" responses can be sent in the headers or trailers block.
        // Check for a valid gRPC status in the headers first, then in the trailers.
        guard let grpcCode = headers?.grpcStatus() ?? trailers?.grpcStatus() else {
            return (.unknown, ConnectError(
                code: .unknown, message: "RPC response missing status", exception: nil,
                details: [], metadata: [:]
            ))
        }

        if grpcCode == .ok {
            return (.ok, nil)
        }

        // Combine headers + trailers into metadata to make error parsing easier for consumers,
        // since gRPC can include error information in either headers or trailers.
        let metadata = (headers ?? [:]).merging(trailers ?? [:]) { $1 }
        return (grpcCode, .init(
            code: grpcCode,
            message: metadata.grpcMessage(),
            exception: nil,
            details: metadata.connectErrorDetailsFromGRPC(),
            metadata: metadata
        ))
    }
}

private extension Trailers {
    func grpcMessage() -> String? {
        return self[HeaderConstants.grpcMessage]?.first?.grpcPercentDecoded()
    }

    func connectErrorDetailsFromGRPC() -> [ConnectError.Detail] {
        return self[HeaderConstants.grpcStatusDetails]?
            .first
            .flatMap { Data(base64Encoded: $0.addingBase64PaddingIfNeeded()) }
            .flatMap { data -> Grpc_Status_V1_Status? in
                return try? ProtoCodec().deserialize(source: data)
            }?
            .details
            .map { protoDetail in
                return ConnectError.Detail(
                    // Include only the type name (last component of the type URL)
                    // to be compatible with SwiftProtobuf's `Google_Protobuf_Any`.
                    type: String(protoDetail.typeURL.split(separator: "/").last!),
                    payload: protoDetail.value
                )
            }
        ?? []
    }
}

private extension String {
    /// grpcPercentEncode/grpcPercentDecode follows RFC 3986 Section 2.1 and the gRPC HTTP/2 spec.
    /// It's a variant of URL-encoding with fewer reserved characters. It's intended
    /// to take UTF-8 encoded text and escape non-ASCII bytes so that they're valid
    /// HTTP/1 headers, while still maximizing readability of the data on the wire.
    ///
    /// The grpc-message trailer (used for human-readable error messages) should be
    /// percent-encoded.
    ///
    /// References:
    ///
    ///    https://github.com/grpc/grpc/blob/master/doc/PROTOCOL-HTTP2.md#responses
    ///    https://datatracker.ietf.org/doc/html/rfc3986#section-2.1
    ///
    /// - returns: A decoded string using the above format.
    func grpcPercentDecoded() -> Self {
        let utf8 = self.utf8
        let endIndex = utf8.endIndex
        var characters = [UInt8]()
        let utf8Percent = UInt8(ascii: "%")
        var index = utf8.startIndex

        while index < endIndex {
            let character = utf8[index]
            if character == utf8Percent {
                let secondIndex = utf8.index(index, offsetBy: 2)
                if secondIndex >= endIndex {
                    return self // Decoding failed
                }

                if let decoded = String(
                    utf8[utf8.index(index, offsetBy: 1) ... secondIndex]
                ).flatMap({ UInt8($0, radix: 16) }) {
                    characters.append(decoded)
                    index = utf8.index(after: secondIndex)
                } else {
                    return self // Decoding failed
                }
            } else {
                characters.append(character)
                index = utf8.index(after: index)
            }
        }

        return String(decoding: characters, as: Unicode.UTF8.self)
    }
}
