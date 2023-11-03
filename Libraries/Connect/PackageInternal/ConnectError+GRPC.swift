// Copyright 2022-2023 The Connect Authors
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
    /// Creates an error using gRPC trailers.
    ///
    /// - parameter trailers: The trailers (or headers, for gRPC-Web) from which to parse the error.
    /// - parameter code: The status code received from the server.
    ///
    /// - returns: An error, if the status indicated an error.
#if COCOAPODS // ConnectNIO is unavailable from CocoaPods, so this can be internal.
    static func fromGRPCTrailers(_ trailers: Trailers, code: Code) -> Self? {
        return self._fromGRPCTrailers(trailers, code: code)
    }
#else
    package static func fromGRPCTrailers(_ trailers: Trailers, code: Code) -> Self? {
        return self._fromGRPCTrailers(trailers, code: code)
    }
#endif

    private static func _fromGRPCTrailers(_ trailers: Trailers, code: Code) -> Self? {
        if code == .ok {
            return nil
        }

        return .init(
            code: code,
            message: trailers.grpcMessage(),
            exception: nil,
            details: trailers.connectErrorDetailsFromGRPC(),
            metadata: [:]
        )
    }
}

private extension Trailers {
    func grpcMessage() -> String? {
        return self[HeaderConstants.grpcMessage]?.first?.grpcPercentDecoded()
    }

    func connectErrorDetailsFromGRPC() -> [ConnectError.Detail] {
        return self[HeaderConstants.grpcStatusDetails]?
            .first
            .flatMap { Data(base64Encoded: $0) }
            .flatMap { data -> Grpc_Status_V1_Status? in
                return try? ProtoCodec().deserialize(source: data)
            }?
            .details
            .compactMap { protoDetail in
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
