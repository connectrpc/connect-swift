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
                let envelopedRequestBody = Envelope.packMessage(
                    request.message ?? Data(), using: self.config.requestCompression
                )

                return HTTPRequest(
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

                guard let responseData = response.message, !responseData.isEmpty else {
                    let code = response.trailers.grpcStatus() ?? response.code
                    return HTTPResponse(
                        code: code,
                        headers: response.headers,
                        message: response.message,
                        trailers: response.trailers,
                        error: response.error ?? ConnectError.fromGRPCTrailers(
                            response.headers, code: code
                        ),
                        tracingInfo: response.tracingInfo
                    )
                }

                let compressionPool = response.headers[HeaderConstants.grpcContentEncoding]?
                    .first
                    .flatMap { self.config.responseCompressionPool(forName: $0) }
                do {
                    let messageData = try Envelope.unpackMessage(
                        responseData,
                        compressionPool: compressionPool
                    ).unpacked
                    let grpcStatus = response.trailers.grpcStatus() ?? .unknown
                    return HTTPResponse(
                        code: grpcStatus,
                        headers: response.headers,
                        message: messageData,
                        trailers: response.trailers,
                        error: grpcStatus == .ok
                            ? nil
                            : ConnectError.fromGRPCTrailers(response.trailers, code: grpcStatus),
                        tracingInfo: response.tracingInfo
                    )
                } catch let error {
                    return HTTPResponse(
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
        fatalError()
//        var responseHeaders: Headers?
//        return Connect.StreamFunction(
//            requestFunction: { request in
//                return HTTPRequest(
//                    url: request.url,
//                    // Override the content type to be gRPC Web.
//                    contentType: "application/grpc-web+\(self.config.codec.name())",
//                    headers: request.headers.addingGRPCHeaders(using: self.config),
//                    message: request.message,
//                    trailers: nil
//                )
//            },
//            requestDataFunction: { data in
//                return Envelope.packMessage(data, using: self.config.requestCompression)
//            },
//            streamResultFunction: { result in
//                switch result {
//                case .headers(let headers):
//                    if let grpcCode = headers.grpcStatus() {
//                        // Headers-only response.
//                        return .complete(
//                            code: grpcCode,
//                            error: ConnectError.fromGRPCWebTrailers(headers, code: grpcCode),
//                            trailers: headers
//                        )
//                    } else {
//                        responseHeaders = headers
//                        return result
//                    }
//
//                case .message(let data):
//                    do {
//                        let responseCompressionPool = responseHeaders?[
//                            HeaderConstants.grpcContentEncoding
//                        ]?.first.flatMap { self.config.responseCompressionPool(forName: $0) }
//                        let (headerByte, unpackedData) = try Envelope.unpackMessage(
//                            data, compressionPool: responseCompressionPool
//                        )
//                        let isTrailers = 0b10000000 & headerByte != 0
//                        if isTrailers {
//                            let trailers = try Trailers.fromGRPCHeadersBlock(unpackedData)
//                            let grpcCode = trailers.grpcStatus() ?? .unknown
//                            if grpcCode == .ok {
//                                return .complete(code: .ok, error: nil, trailers: trailers)
//                            } else {
//                                return .complete(
//                                    code: grpcCode,
//                                    error: ConnectError.fromGRPCWebTrailers(
//                                        trailers, code: grpcCode
//                                    ),
//                                    trailers: trailers
//                                )
//                            }
//                        } else {
//                            return .message(unpackedData)
//                        }
//                    } catch let error {
//                        // TODO: Close the stream here?
//                        return .complete(code: .unknown, error: error, trailers: nil)
//                    }
//
//                case .complete:
//                    return result
//                }
//            }
//        )
    }
}
