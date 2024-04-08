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
        let envelopedRequestBody = Envelope.packMessage(
            request.message ?? Data(), using: self.config.requestCompression
        )

        proceed(.success(HTTPRequest(
            url: request.url,
            headers: request.headers.addingGRPCHeaders(using: self.config, grpcWeb: false),
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

        let (grpcCode, connectError) = ConnectError.parseGRPCHeaders(
            response.headers,
            trailers: response.trailers
        )
        guard grpcCode == .ok, let rawData = response.message, !rawData.isEmpty else {
            proceed(HTTPResponse(
                code: grpcCode,
                headers: response.headers,
                message: response.message,
                trailers: response.trailers,
                error: connectError ?? response.error,
                tracingInfo: response.tracingInfo
            ))
            return
        }

        let compressionPool = response
            .headers[HeaderConstants.grpcContentEncoding]?
            .first
            .flatMap { self.config.responseCompressionPool(forName: $0) }
        do {
            let messageData = try Envelope.unpackMessage(
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
            headers: request.headers.addingGRPCHeaders(using: self.config, grpcWeb: false),
            message: request.message,
            method: request.method,
            trailers: nil,
            idempotencyLevel: request.idempotencyLevel
        )))
    }

    @Sendable
    func handleStreamRawInput(_ input: Data, proceed: @escaping (Data) -> Void) {
        proceed(Envelope.packMessage(input, using: self.config.requestCompression))
    }

    @Sendable
    func handleStreamRawResult(
        _ result: StreamResult<Data>,
        proceed: @escaping (StreamResult<Data>) -> Void
    ) {
        switch result {
        case .headers(let headers):
            self.streamResponseHeaders.value = headers
            proceed(result)

        case .message(let rawData):
            do {
                let responseCompressionPool = self.streamResponseHeaders.value?[
                    HeaderConstants.grpcContentEncoding
                ]?.first.flatMap { self.config.responseCompressionPool(forName: $0) }
                proceed(.message(try Envelope.unpackMessage(
                    rawData, compressionPool: responseCompressionPool
                ).unpacked))
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

            let (grpcCode, connectError) = ConnectError.parseGRPCHeaders(
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
