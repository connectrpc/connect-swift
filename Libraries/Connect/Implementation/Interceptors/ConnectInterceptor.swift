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

/// Implementation of the Connect protocol as an interceptor.
/// https://connectrpc.com/docs/protocol
struct ConnectInterceptor {
    private let config: ProtocolClientConfig

    private static let protocolVersion = "1"

    init(config: ProtocolClientConfig) {
        self.config = config
    }
}

extension ConnectInterceptor: Interceptor {
    func unaryFunction() -> UnaryFunction {
        return UnaryFunction { request, proceed in
            var headers = request.headers
            headers[HeaderConstants.connectProtocolVersion] = [Self.protocolVersion]
            headers[HeaderConstants.acceptEncoding] = self.config.acceptCompressionPoolNames()

            let requestBody = request.message ?? Data()
            let finalRequestBody: Data
            if let compression = self.config.requestCompression,
               compression.shouldCompress(requestBody)
            {
                do {
                    finalRequestBody = try compression.pool.compress(data: requestBody)
                    headers[HeaderConstants.contentEncoding] = [compression.pool.name()]
                } catch {
                    finalRequestBody = requestBody
                }
            } else {
                finalRequestBody = requestBody
            }

            proceed(.success(self.config.transformToGETIfNeeded(HTTPRequest(
                url: request.url,
                contentType: request.contentType,
                headers: headers,
                message: finalRequestBody,
                method: .post,
                trailers: nil,
                idempotencyLevel: request.idempotencyLevel
            ))))
        } responseFunction: { response, proceed in
            let trailerPrefix = "trailer-"
            let headers = response.headers.filter { header in
                return header.key != HeaderConstants.contentEncoding
                && !header.key.hasPrefix(trailerPrefix)
            }
            let trailers = response.headers
                .filter { $0.key.hasPrefix(trailerPrefix) }
                .reduce(into: Trailers(), { trailers, current in
                    trailers[
                        String(current.key.dropFirst(trailerPrefix.count))
                    ] = current.value
                })

            if let encoding = response.headers[HeaderConstants.contentEncoding]?.first,
               let compressionPool = self.config.responseCompressionPool(forName: encoding),
               let message = response.message.flatMap({ data in
                   return try? compressionPool.decompress(data: data)
               })
            {
                proceed(HTTPResponse(
                    code: response.code,
                    headers: headers,
                    message: message,
                    trailers: trailers,
                    error: response.error,
                    tracingInfo: response.tracingInfo
                ))
            } else {
                proceed(HTTPResponse(
                    code: response.code,
                    headers: headers,
                    message: response.message,
                    trailers: trailers,
                    error: response.error,
                    tracingInfo: response.tracingInfo
                ))
            }
        }
    }

    func streamFunction() -> StreamFunction {
        let responseHeaders = Locked<Headers?>(nil)
        return StreamFunction { request, proceed in
            var headers = request.headers
            headers[HeaderConstants.connectProtocolVersion] = [Self.protocolVersion]
            headers[HeaderConstants.connectStreamingContentEncoding] = self.config
                .requestCompression.map { [$0.pool.name()] }
            headers[HeaderConstants.connectStreamingAcceptEncoding] = self.config
                .acceptCompressionPoolNames()
            proceed(.success(HTTPRequest(
                url: request.url,
                contentType: request.contentType,
                headers: headers,
                message: request.message,
                method: request.method,
                trailers: nil,
                idempotencyLevel: request.idempotencyLevel
            )))
        } requestDataFunction: { data, proceed in
            proceed(Envelope.packMessage(data, using: self.config.requestCompression))
        } streamResultFunction: { result, proceed in
            switch result {
            case .headers(let headers):
                responseHeaders.value = headers
                proceed(result)

            case .message(let data):
                do {
                    let responseCompressionPool = responseHeaders.value?[
                        HeaderConstants.connectStreamingContentEncoding
                    ]?.first.flatMap { self.config.responseCompressionPool(forName: $0) }
                    let (headerByte, message) = try Envelope.unpackMessage(
                        data, compressionPool: responseCompressionPool
                    )
                    let isEndStream = 0b00000010 & headerByte != 0
                    if isEndStream {
                        // Expect a valid Connect end stream response, which can simply be {}.
                        // https://connectrpc.com/docs/protocol#error-end-stream
                        let response = try JSONDecoder().decode(
                            ConnectEndStreamResponse.self, from: message
                        )
                        proceed(.complete(
                            code: response.error?.code ?? .ok,
                            error: response.error,
                            trailers: response.metadata
                        ))
                    } else {
                        proceed(.message(message))
                    }
                } catch let error {
                    // TODO: Close the stream here?
                    proceed(.complete(code: .unknown, error: error, trailers: nil))
                }

            case .complete(let code, let error, let trailers):
                if code != .ok && error == nil {
                    proceed(.complete(
                        code: code,
                        error: ConnectError.from(
                            code: code,
                            headers: responseHeaders.value ?? [:],
                            source: nil
                        ),
                        trailers: trailers
                    ))
                } else {
                    proceed(result)
                }
            }
        }
    }
}

private extension ProtocolClientConfig {
    func transformToGETIfNeeded(_ request: HTTPRequest) -> HTTPRequest {
        guard self.shouldUseUnaryGET(for: request) else {
            return request
        }

        var components = URLComponents(url: request.url, resolvingAgainstBaseURL: true)
        components?.queryItems = [
            URLQueryItem(name: "base64", value: "1"),
            URLQueryItem(
                name: "compression",
                value: request.headers[HeaderConstants.contentEncoding]?.first
            ),
            URLQueryItem(name: "connect", value: "v1"),
            URLQueryItem(name: "encoding", value: self.codec.name()),
            URLQueryItem(name: "message", value: request.message?.base64EncodedString()),
        ]
        guard let url = components?.url else {
            return request
        }

        print("**URL: \(url)")
        return HTTPRequest(
            url: url,
            contentType: request.contentType,
            headers: request.headers,
            message: nil,
            method: .get,
            trailers: request.trailers,
            idempotencyLevel: request.idempotencyLevel
        )
    }

    private func shouldUseUnaryGET(for request: HTTPRequest) -> Bool {
        guard request.idempotencyLevel == .noSideEffects else {
            return false
        }

        switch self.getConfiguration {
        case .disabled:
            return false
        case .unlimitedURLBytes:
            return true
        case .cappedURLBytes(let maxBytes):
            return (request.message?.count ?? 0) <= maxBytes
        }
    }
}
