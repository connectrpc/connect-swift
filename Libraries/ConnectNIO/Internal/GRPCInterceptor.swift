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
        return Connect.UnaryFunction(
            requestFunction: { request in
                // gRPC unary payloads are enveloped.
                let envelopedRequestBody = Connect.Envelope.packMessage(
                    request.message ?? Data(), using: self.config.requestCompression
                )

                return Connect.HTTPRequest(
                    url: request.url,
                    // Override the content type to be gRPC.
                    contentType: "application/grpc+\(self.config.codec.name())",
                    headers: request.headers.addingGRPCHeaders(using: self.config),
                    message: envelopedRequestBody,
                    trailers: nil
                )
            },
            responseFunction: { response in
                guard response.code == .ok else {
                    // Invalid gRPC response - expects HTTP 200. Potentially a network error.
                    return response
                }

                let (grpcCode, connectError) = grpcResult(
                    fromHeaders: response.headers, trailers: response.trailers
                )
                guard let responseData = response.message, !responseData.isEmpty else {
                    return Connect.HTTPResponse(
                        code: grpcCode,
                        headers: response.headers,
                        message: response.message,
                        trailers: response.trailers,
                        error: connectError ?? response.error,
                        tracingInfo: response.tracingInfo
                    )
                }

                let compressionPool = response
                    .headers[Connect.HeaderConstants.grpcContentEncoding]?
                    .first
                    .flatMap { self.config.responseCompressionPool(forName: $0) }
                do {
                    let messageData = try Connect.Envelope.unpackMessage(
                        responseData,
                        compressionPool: compressionPool
                    ).unpacked
                    return Connect.HTTPResponse(
                        code: grpcCode,
                        headers: response.headers,
                        message: messageData,
                        trailers: response.trailers,
                        error: grpcCode == .ok ? nil : connectError,
                        tracingInfo: response.tracingInfo
                    )
                } catch let error {
                    return Connect.HTTPResponse(
                        code: .unknown,
                        headers: response.headers,
                        message: response.message,
                        trailers: response.trailers,
                        error: error,
                        tracingInfo: response.tracingInfo
                    )
                }
            },
            responseMetricsFunction: { $0 }
        )
    }

    func streamFunction() -> Connect.StreamFunction {
        let responseHeaders = Locked<Headers?>(nil)
        return Connect.StreamFunction(
            requestFunction: { request in
                return Connect.HTTPRequest(
                    url: request.url,
                    // Override the content type to be gRPC.
                    contentType: "application/grpc+\(self.config.codec.name())",
                    headers: request.headers.addingGRPCHeaders(using: self.config),
                    message: request.message,
                    trailers: nil
                )
            },
            requestDataFunction: { data in
                return Connect.Envelope.packMessage(data, using: self.config.requestCompression)
            },
            streamResultFunction: { result in
                switch result {
                case .headers(let headers):
                    responseHeaders.value = headers
                    return result

                case .message(let data):
                    do {
                        let responseCompressionPool = responseHeaders.value?[
                            Connect.HeaderConstants.grpcContentEncoding
                        ]?.first.flatMap { self.config.responseCompressionPool(forName: $0) }
                        return .message(try Connect.Envelope.unpackMessage(
                            data,
                            compressionPool: responseCompressionPool
                        ).unpacked)
                    } catch let error {
                        // TODO: Close the stream here?
                        return .complete(code: .unknown, error: error, trailers: nil)
                    }

                case .complete(let code, let error, let trailers):
                    guard code == .ok else {
                        // Invalid gRPC response - expects HTTP 200. Potentially a network error.
                        return .complete(code: code, error: error, trailers: trailers)
                    }

                    let (grpcCode, connectError) = grpcResult(
                        fromHeaders: responseHeaders.value, trailers: trailers
                    )
                    if grpcCode == .ok {
                        return .complete(
                            code: .ok,
                            error: nil,
                            trailers: trailers
                        )
                    } else {
                        return .complete(
                            code: grpcCode,
                            error: connectError ?? error,
                            trailers: trailers
                        )
                    }
                }
            }
        )
    }
}

private func grpcResult(
    fromHeaders headers: Headers?, trailers: Trailers?
) -> (code: Code, error: ConnectError?) {
    let finalTrailers: Trailers
    if let trailers = trailers, !trailers.isEmpty {
        finalTrailers = trailers
    } else if let headers = headers {
        // "Trailers-only" responses can be sent in the headers block.
        // If no trailers are present, look in the headers for the necessary information.
        finalTrailers = headers
    } else {
        return (.unknown, nil)
    }
    
    let grpcCode = finalTrailers.grpcStatus() ?? .unknown
    return (grpcCode, .fromGRPCTrailers(finalTrailers, code: grpcCode))
}
