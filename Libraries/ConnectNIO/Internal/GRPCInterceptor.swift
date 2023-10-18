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

import Connect
import Foundation

/// Implementation of the gRPC protocol as an interceptor.
/// https://github.com/grpc/grpc/blob/master/doc/PROTOCOL-HTTP2.md
struct GRPCInterceptor {
    private let config: Connect.ProtocolClientConfig

    init(config: Connect.ProtocolClientConfig) {
        self.config = config
    }
}

extension GRPCInterceptor: Connect.Interceptor {
    func unaryFunction() -> Connect.UnaryFunction {
        return Connect.UnaryFunction { request, proceed in
            // gRPC unary payloads are enveloped.
            let envelopedRequestBody = Connect.Envelope.packMessage(
                request.message ?? Data(), using: self.config.requestCompression
            )

            proceed(.success(Connect.HTTPRequest(
                url: request.url,
                // Override the content type to be gRPC.
                contentType: "application/grpc+\(self.config.codec.name())",
                headers: request.headers.addingGRPCHeaders(using: self.config, grpcWeb: false),
                message: envelopedRequestBody,
                method: request.method,
                trailers: nil,
                idempotencyLevel: request.idempotencyLevel
            )))
        } responseFunction: { response, proceed in
            guard response.code == .ok else {
                // Invalid gRPC response - expects HTTP 200. Potentially a network error.
                proceed(response)
                return
            }

            let (grpcCode, connectError) = self.grpcResult(
                fromHeaders: response.headers, trailers: response.trailers
            )
            guard grpcCode == .ok, let rawData = response.message, !rawData.isEmpty else {
                proceed(Connect.HTTPResponse(
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
                .headers[Connect.HeaderConstants.grpcContentEncoding]?
                .first
                .flatMap { self.config.responseCompressionPool(forName: $0) }
            do {
                let messageData = try Connect.Envelope.unpackMessage(
                    rawData, compressionPool: compressionPool
                ).unpacked
                proceed(Connect.HTTPResponse(
                    code: grpcCode,
                    headers: response.headers,
                    message: messageData,
                    trailers: response.trailers,
                    error: nil,
                    tracingInfo: response.tracingInfo
                ))
            } catch let error {
                proceed(Connect.HTTPResponse(
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

    func streamFunction() -> Connect.StreamFunction {
        let responseHeaders = Locked<Headers?>(nil)
        return Connect.StreamFunction { request, proceed in
            proceed(.success(Connect.HTTPRequest(
                url: request.url,
                // Override the content type to be gRPC.
                contentType: "application/grpc+\(self.config.codec.name())",
                headers: request.headers.addingGRPCHeaders(using: self.config, grpcWeb: false),
                message: request.message,
                method: request.method,
                trailers: nil,
                idempotencyLevel: request.idempotencyLevel
            )))
        } requestDataFunction: { data, proceed in
            proceed(Connect.Envelope.packMessage(data, using: self.config.requestCompression))
        } streamResultFunction: { result, proceed in
            switch result {
            case .headers(let headers):
                responseHeaders.value = headers
                proceed(result)

            case .message(let rawData):
                do {
                    let responseCompressionPool = responseHeaders.value?[
                        Connect.HeaderConstants.grpcContentEncoding
                    ]?.first.flatMap { self.config.responseCompressionPool(forName: $0) }
                    proceed(.message(try Connect.Envelope.unpackMessage(
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

                let (grpcCode, connectError) = self.grpcResult(
                    fromHeaders: responseHeaders.value, trailers: trailers
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

    private func grpcResult(
        fromHeaders headers: Headers?, trailers: Trailers?
    ) -> (code: Code, error: ConnectError?) {
        // "Trailers-only" responses can be sent in the headers or trailers block.
        // Check for a valid gRPC status in the headers first, then in the trailers.
        if let headers = headers, let grpcCode = headers.grpcStatus() {
            return (grpcCode, .fromGRPCTrailers(headers, code: grpcCode))
        } else if let trailers = trailers, let grpcCode = trailers.grpcStatus() {
            return (grpcCode, .fromGRPCTrailers(trailers, code: grpcCode))
        } else {
            return (.unknown, nil)
        }
    }
}
