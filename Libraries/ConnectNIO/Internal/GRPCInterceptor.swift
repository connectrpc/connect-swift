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

import Connect
import Foundation
import NIOConcurrencyHelpers

/// Implementation of the gRPC protocol as an interceptor.
/// https://github.com/grpc/grpc/blob/master/doc/PROTOCOL-HTTP2.md
final class GRPCInterceptor: Interceptor {
    private let config: ProtocolClientConfig
    private let streamResponseHeaders = Locked<Headers?>(nil)

    init(config: ProtocolClientConfig) {
        self.config = config
    }
}

extension GRPCInterceptor: UnaryInterceptor {
    @Sendable
    func handleUnaryRawRequest(
        _ request: HTTPRequest<Data?>,
        proceed: @escaping (Result<HTTPRequest<Data?>, ConnectError>) -> Void
    ) {
        // gRPC unary payloads are enveloped.
        let envelopedRequestBody = Envelope._packMessage(
            request.message ?? Data(), using: self.config.requestCompression
        )

        proceed(.success(HTTPRequest(
            url: request.url,
            headers: request.headers._addingGRPCHeaders(using: self.config, grpcWeb: false),
            message: envelopedRequestBody,
            method: request.method,
            trailers: nil,
            idempotencyLevel: request.idempotencyLevel
        )))
    }

    @Sendable
    func handleUnaryRawResponse(
        _ response: HTTPResponse,
        proceed: @escaping (HTTPResponse) -> Void
    ) {
        guard response.code == .ok else {
            // Invalid gRPC response - expects HTTP 200. Potentially a network error.
            proceed(response)
            return
        }

        let contentType = response.headers[HeaderConstants.contentType]?.first ?? ""
        if !self.contentTypeIsExpectedGRPC(contentType) {
            // If content-type looks like it could be a gRPC server's response, consider
            // this an internal error.
            let code: Code = self.contentTypeIsGRPC(contentType) ? .internalError : .unknown
            proceed(HTTPResponse(
                code: code, headers: response.headers, message: nil, trailers: response.trailers,
                error: ConnectError(code: code, message: "unexpected content-type: \(contentType)"),
                tracingInfo: response.tracingInfo
            ))
            return
        }

        let (grpcCode, connectError) = ConnectError._parseGRPCHeaders(
            response.headers,
            trailers: response.trailers
        )
        guard grpcCode == .ok, let rawData = response.message, !rawData.isEmpty else {
            if response.trailers._grpcStatus() == nil && response.message?.isEmpty == false {
                proceed(HTTPResponse(
                    code: .internalError,
                    headers: response.headers,
                    message: response.message,
                    trailers: response.trailers,
                    error: ConnectError(
                        code: .internalError,
                        message: "unary response message should be followed by trailers"
                    ),
                    tracingInfo: response.tracingInfo
                ))
            } else if grpcCode == .ok {
                proceed(HTTPResponse(
                    code: .unimplemented,
                    headers: response.headers,
                    message: response.message,
                    trailers: response.trailers,
                    error: ConnectError(
                        code: .unimplemented, message: "unary response has no message"
                    ),
                    tracingInfo: response.tracingInfo
                ))
            } else {
                proceed(HTTPResponse(
                    code: grpcCode,
                    headers: response.headers,
                    message: response.message,
                    trailers: response.trailers,
                    error: connectError ?? response.error,
                    tracingInfo: response.tracingInfo
                ))
            }
            return
        }

        let compressionPool = response
            .headers[HeaderConstants.grpcContentEncoding]?
            .first
            .flatMap { self.config.responseCompressionPool(forName: $0) }
        if compressionPool == nil && Envelope._isCompressed(rawData) {
            proceed(HTTPResponse(
                code: .internalError, headers: response.headers, message: nil,
                trailers: response.trailers, error: ConnectError(
                    code: .internalError, message: "received unexpected compressed message"
                ), tracingInfo: response.tracingInfo
            ))
            return
        } else if Envelope.containsMultipleGRPCMessages(rawData) {
            proceed(HTTPResponse(
                code: .unimplemented,
                headers: response.headers,
                message: nil,
                trailers: response.trailers,
                error: ConnectError(
                    code: .unimplemented, message: "unary response has multiple messages"
                ),
                tracingInfo: response.tracingInfo
            ))
            return
        }

        do {
            let messageData = try Envelope._unpackMessage(
                rawData, compressionPool: compressionPool
            ).unpacked
            proceed(HTTPResponse(
                code: grpcCode,
                headers: response.headers,
                message: messageData,
                trailers: response.trailers,
                error: nil,
                tracingInfo: response.tracingInfo
            ))
        } catch let error {
            proceed(HTTPResponse(
                code: .unknown,
                headers: response.headers,
                message: response.message,
                trailers: response.trailers,
                error: error,
                tracingInfo: response.tracingInfo
            ))
        }
    }
}

extension GRPCInterceptor: StreamInterceptor {
    @Sendable
    func handleStreamStart(
        _ request: HTTPRequest<Void>,
        proceed: @escaping (Result<HTTPRequest<Void>, ConnectError>) -> Void
    ) {
        proceed(.success(HTTPRequest(
            url: request.url,
            headers: request.headers._addingGRPCHeaders(using: self.config, grpcWeb: false),
            message: request.message,
            method: request.method,
            trailers: nil,
            idempotencyLevel: request.idempotencyLevel
        )))
    }

    @Sendable
    func handleStreamRawInput(_ input: Data, proceed: @escaping (Data) -> Void) {
        proceed(Envelope._packMessage(input, using: self.config.requestCompression))
    }

    @Sendable
    func handleStreamRawResult(
        _ result: StreamResult<Data>,
        proceed: @escaping (StreamResult<Data>) -> Void
    ) {
        switch result {
        case .headers(let headers):
            self.streamResponseHeaders.value = headers

            let contentType = headers[HeaderConstants.contentType]?.first ?? ""
            if !self.contentTypeIsExpectedGRPC(contentType) {
                // If content-type looks like it could be a gRPC server's response, consider
                // this an internal error.
                let code: Code = self.contentTypeIsGRPC(contentType) ? .internalError : .unknown
                proceed(.complete(
                    code: code, error: ConnectError(
                        code: code, message: "unexpected content-type: \(contentType)"
                    ), trailers: headers
                ))
                return
            }

            proceed(result)

        case .message(let rawData):
            do {
                let responseCompressionPool = self.streamResponseHeaders.value?[
                    HeaderConstants.grpcContentEncoding
                ]?.first.flatMap { self.config.responseCompressionPool(forName: $0) }
                if responseCompressionPool == nil && Envelope._isCompressed(rawData) {
                    proceed(.complete(
                        code: .internalError, error: ConnectError(
                            code: .internalError, message: "received unexpected compressed message"
                        ), trailers: [:]
                    ))
                    return
                }

                let unpackedMessage = try Envelope._unpackMessage(
                    rawData, compressionPool: responseCompressionPool
                ).unpacked
                proceed(.message(unpackedMessage))
            } catch let error {
                // TODO: Close the stream here?
                proceed(.complete(code: .unknown, error: error, trailers: nil))
            }

        case .complete(let code, let error, let trailers):
            guard code == .ok else {
                // Invalid gRPC response - expects HTTP 200. Potentially a network error.
                proceed(.complete(code: code, error: error, trailers: trailers))
                return
            }

            let (grpcCode, connectError) = ConnectError._parseGRPCHeaders(
                self.streamResponseHeaders.value,
                trailers: trailers
            )
            if grpcCode == .ok {
                proceed(.complete(
                    code: .ok,
                    error: nil,
                    trailers: trailers
                ))
            } else {
                proceed(.complete(
                    code: grpcCode,
                    error: connectError ?? error,
                    trailers: trailers
                ))
            }
        }
    }

    // MARK: - Private

    private func contentTypeIsGRPC(_ contentType: String) -> Bool {
        return contentType == "application/grpc"
        || contentType.hasPrefix("application/grpc+")
    }

    private func contentTypeIsExpectedGRPC(_ contentType: String) -> Bool {
        let codecName = self.config.codec.name()
        return (codecName == "proto" && contentType == "application/grpc")
        || contentType == "application/grpc+\(codecName)"
    }
}

private extension Envelope {
    static func containsMultipleGRPCMessages(_ packedData: Data) -> Bool {
        let messageLength = self._messageLength(forPackedData: packedData)
        return packedData.count > messageLength + self._prefixLength
    }
}

private final class Locked<T>: @unchecked Sendable {
    private let lock = NIOLock()
    private var wrappedValue: T

    /// Thread-safe access to the underlying value.
    var value: T {
        get { self.lock.withLock { self.wrappedValue } }
        set { self.lock.withLock { self.wrappedValue = newValue } }
    }

    init(_ value: T) {
        self.wrappedValue = value
    }
}
