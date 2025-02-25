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

import Foundation

/// Implementation of the gRPC-Web protocol as an interceptor.
/// https://github.com/grpc/grpc/blob/master/doc/PROTOCOL-WEB.md
final class GRPCWebInterceptor: Interceptor {
    private let config: ProtocolClientConfig
    private let streamResponseHeaders = Locked<Headers?>(nil)

    init(config: ProtocolClientConfig) {
        self.config = config
    }
}

extension GRPCWebInterceptor: UnaryInterceptor {
    @Sendable
    func handleUnaryRawRequest(
        _ request: HTTPRequest<Data?>,
        proceed: @escaping (Result<HTTPRequest<Data?>, ConnectError>) -> Void
    ) {
        // gRPC-Web unary payloads are enveloped.
        let envelopedRequestBody = Envelope._packMessage(
            request.message ?? Data(), using: self.config.requestCompression
        )
        proceed(.success(HTTPRequest(
            url: request.url,
            headers: request.headers._addingGRPCHeaders(using: self.config, grpcWeb: true),
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
            // Invalid gRPC-Web response - expects HTTP 200. Potentially a network error.
            proceed(response)
            return
        }

        guard let responseData = response.message, !responseData.isEmpty else {
            let (grpcCode, connectError) = ConnectError._parseGRPCHeaders(
                response.headers,
                trailers: response.trailers
            )
            if grpcCode != .ok || connectError != nil {
                proceed(HTTPResponse(
                    // Rewrite the gRPC code if it is "ok" but `connectError` is non-nil.
                    code: grpcCode == .ok ? .unknown : grpcCode,
                    headers: response.headers,
                    message: response.message,
                    trailers: response.trailers,
                    error: connectError,
                    tracingInfo: response.tracingInfo
                ))
            } else {
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
            }
            return
        }

        let contentType = response.headers[HeaderConstants.contentType]?.first ?? ""
        if response.code == .ok && !self.contentTypeIsExpectedGRPCWeb(contentType) {
            // If content-type looks like it could be a gRPC server's response, consider
            // this an internal error.
            let code: Code = self.contentTypeIsGRPCWeb(contentType) ? .internalError : .unknown
            proceed(HTTPResponse(
                code: code, headers: response.headers, message: nil, trailers: response.trailers,
                error: ConnectError(code: code, message: "unexpected content-type: \(contentType)"),
                tracingInfo: response.tracingInfo
            ))
            return
        }

        let compressionPool = response.headers[HeaderConstants.grpcContentEncoding]?
            .first
            .flatMap { self.config.responseCompressionPool(forName: $0) }
        if compressionPool == nil && Envelope._isCompressed(responseData) {
            proceed(HTTPResponse(
                code: .internalError, headers: response.headers, message: nil,
                trailers: response.trailers,
                error: ConnectError(
                    code: .internalError, message: "received unexpected compressed message"
                ),
                tracingInfo: response.tracingInfo
            ))
            return
        }

        do {
            // gRPC Web returns data in 2 chunks (either/both of which may be compressed):
            // 1. OPTIONAL (when not trailers-only): The (headers and length prefixed)
            //    message data.
            // 2. The (headers and length prefixed) trailers data.
            // https://github.com/grpc/grpc/blob/master/doc/PROTOCOL-WEB.md
            let firstChunkLength = Envelope._messageLength(forPackedData: responseData)
            let prefixedFirstChunkLength = Envelope._prefixLength + firstChunkLength
            let firstChunk = try Envelope._unpackMessage(
                Data(responseData.prefix(upTo: prefixedFirstChunkLength)),
                compressionPool: compressionPool
            )
            let isTrailersOnly = 0b10000000 & firstChunk.headerByte != 0
            if isTrailersOnly {
                let unpackedTrailers = try Trailers.fromGRPCHeadersBlock(
                    firstChunk.unpacked
                )
                proceed(response.withHandledGRPCWebTrailers(unpackedTrailers, message: nil))
            } else {
                let trailersData = Data(responseData.suffix(from: prefixedFirstChunkLength))
                let unpackedTrailers = try Trailers.fromGRPCHeadersBlock(
                    try Envelope._unpackMessage(
                        trailersData, compressionPool: compressionPool
                    ).unpacked
                )
                proceed(response.withHandledGRPCWebTrailers(
                    unpackedTrailers,
                    message: firstChunk.unpacked
                ))
            }
        } catch let error {
            proceed(HTTPResponse(
                code: .unimplemented,
                headers: response.headers,
                message: response.message,
                trailers: response.trailers,
                error: error,
                tracingInfo: response.tracingInfo
            ))
        }
    }
}

extension GRPCWebInterceptor: StreamInterceptor {
    @Sendable
    func handleStreamStart(
        _ request: HTTPRequest<Void>,
        proceed: @escaping (Result<HTTPRequest<Void>, ConnectError>) -> Void
    ) {
        proceed(.success(HTTPRequest(
            url: request.url,
            headers: request.headers._addingGRPCHeaders(using: self.config, grpcWeb: true),
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
            let contentType = headers[HeaderConstants.contentType]?.first ?? ""
            if !self.contentTypeIsExpectedGRPCWeb(contentType) {
                // If content-type looks like it could be a gRPC server's response, consider
                // this an internal error.
                let code: Code = self.contentTypeIsGRPCWeb(contentType) ? .internalError : .unknown
                proceed(.complete(
                    code: code, error: ConnectError(
                        code: code, message: "unexpected content-type: \(contentType)"
                    ), trailers: headers
                ))
                return
            }

            if let grpcCode = headers._grpcStatus() {
                // Headers-only response.
                proceed(.complete(
                    code: grpcCode,
                    error: ConnectError._parseGRPCHeaders(nil, trailers: headers).error,
                    trailers: headers
                ))
            } else {
                self.streamResponseHeaders.value = headers
                proceed(result)
            }

        case .message(let data):
            do {
                let responseCompressionPool = self.streamResponseHeaders.value?[
                    HeaderConstants.grpcContentEncoding
                ]?.first.flatMap { self.config.responseCompressionPool(forName: $0) }
                let (headerByte, unpackedData) = try Envelope._unpackMessage(
                    data, compressionPool: responseCompressionPool
                )
                let isTrailers = 0b10000000 & headerByte != 0
                if isTrailers {
                    let trailers = try Trailers.fromGRPCHeadersBlock(unpackedData)
                    let (grpcCode, error) = ConnectError._parseGRPCHeaders(
                        self.streamResponseHeaders.value, trailers: trailers
                    )
                    if grpcCode == .ok {
                        proceed(.complete(code: .ok, error: nil, trailers: trailers))
                    } else {
                        proceed(.complete(
                            code: grpcCode,
                            error: error,
                            trailers: trailers
                        ))
                    }
                } else {
                    proceed(.message(unpackedData))
                }
            } catch let error {
                // TODO: Close the stream here?
                proceed(.complete(code: .unknown, error: error, trailers: nil))
            }

        case .complete:
            proceed(result)
        }
    }

    // MARK: - Private

    private func contentTypeIsGRPCWeb(_ contentType: String) -> Bool {
        return contentType == "application/grpc-web"
        || contentType.hasPrefix("application/grpc-web+")
    }

    private func contentTypeIsExpectedGRPCWeb(_ contentType: String) -> Bool {
        let codecName = self.config.codec.name()
        return (codecName == "proto" && contentType == "application/grpc-web")
        || contentType == "application/grpc-web+\(codecName)"
    }
}

private struct TrailersDecodingError: Error {}

private extension Trailers {
    static func fromGRPCHeadersBlock(_ source: Data) throws -> Self {
        guard let string = String(data: source, encoding: .utf8) else {
            throw TrailersDecodingError()
        }

        // Decode trailers based on gRPC Web spec:
        // https://github.com/grpc/grpc/blob/master/doc/PROTOCOL-WEB.md
        return string
            .split(separator: "\r\n")
            .reduce(into: Trailers()) { trailers, line in
                guard let separatorIndex = line.firstIndex(of: ":") else {
                    return
                }

                let trailerName = String(line.prefix(upTo: separatorIndex)).lowercased()
                let trailerValues = String(line.suffix(from: separatorIndex + 1))
                for value in trailerValues.components(separatedBy: ",") {
                    trailers[trailerName, default: []].append(
                        value.trimmingCharacters(in: .whitespaces)
                    )
                }
            }
    }
}

private extension HTTPResponse {
    func withHandledGRPCWebTrailers(_ trailers: Trailers, message: Data?) -> Self {
        let (grpcCode, error) = ConnectError._parseGRPCHeaders(self.headers, trailers: trailers)
        if grpcCode != .ok || error != nil {
            return HTTPResponse(
                // Rewrite the gRPC code if it is "ok" but `connectError` is non-nil.
                code: grpcCode == .ok ? .unknown : grpcCode,
                headers: self.headers,
                message: nil,
                trailers: trailers,
                error: error,
                tracingInfo: self.tracingInfo
            )
        } else if message == nil {
            return HTTPResponse(
                code: .unimplemented,
                headers: self.headers,
                message: nil,
                trailers: trailers,
                error: ConnectError(code: .unimplemented, message: "unary response has no message"),
                tracingInfo: self.tracingInfo
            )
        } else {
            return HTTPResponse(
                code: grpcCode,
                headers: self.headers,
                message: message,
                trailers: trailers,
                error: nil,
                tracingInfo: self.tracingInfo
            )
        }
    }
}
