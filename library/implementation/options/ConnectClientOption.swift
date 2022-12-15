import Foundation

/// Enables the client to speak using the Connect protocol:
/// https://connect.build/docs
public struct ConnectClientOption {
    public init() {}
}

extension ConnectClientOption: ProtocolClientOption {
    public func apply(_ config: ProtocolClientConfig) -> ProtocolClientConfig {
        return config.clone(interceptors: [ConnectInterceptor.init] + config.interceptors)
    }
}

/// The Connect protocol is implemented as an interceptor in the request/response chain.
private struct ConnectInterceptor {
    private let config: ProtocolClientConfig

    private static let protocolVersion = "1"

    init(config: ProtocolClientConfig) {
        self.config = config
    }
}

extension ConnectInterceptor: Interceptor {
    func wrapUnary() -> UnaryFunction {
        return UnaryFunction(
            requestFunction: { request in
                var headers = request.headers
                headers[HeaderConstants.connectProtocolVersion] = [Self.protocolVersion]
                headers[HeaderConstants.acceptEncoding] = self.config.acceptCompressionPoolNames()

                let requestBody = request.message ?? Data()
                let finalRequestBody: Data
                if Envelope.shouldCompress(
                    requestBody, compressionMinBytes: self.config.compressionMinBytes
                ), let compressionPool = self.config.requestCompressionPool() {
                    do {
                        headers[HeaderConstants.contentEncoding] = [
                            type(of: compressionPool).name(),
                        ]
                        finalRequestBody = try compressionPool.compress(data: requestBody)
                    } catch {
                        finalRequestBody = requestBody
                    }
                } else {
                    finalRequestBody = requestBody
                }

                return HTTPRequest(
                    target: request.target,
                    contentType: request.contentType,
                    headers: headers,
                    message: finalRequestBody
                )
            },
            responseFunction: { response in
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
                   let compressionPool = self.config.compressionPools[encoding],
                   let message = response.message.flatMap({ data in
                       return try? compressionPool.decompress(data: data)
                   })
                {
                    return HTTPResponse(
                        code: response.code,
                        headers: headers,
                        message: message,
                        trailers: trailers,
                        error: response.error
                    )
                } else {
                    return HTTPResponse(
                        code: response.code,
                        headers: headers,
                        message: response.message,
                        trailers: trailers,
                        error: response.error
                    )
                }
            }
        )
    }

    func wrapStream() -> StreamingFunction {
        var responseHeaders: Headers?
        return StreamingFunction(
            requestFunction: { request in
                var headers = request.headers
                headers[HeaderConstants.connectProtocolVersion] = [Self.protocolVersion]
                headers[HeaderConstants.connectStreamingContentEncoding] = self.config
                    .compressionName.map { [$0] }
                headers[HeaderConstants.connectStreamingAcceptEncoding] = self.config
                    .acceptCompressionPoolNames()
                return HTTPRequest(
                    target: request.target,
                    contentType: request.contentType,
                    headers: headers,
                    message: request.message
                )
            },
            requestDataFunction: { data in
                return Envelope.packMessage(
                    data,
                    compressionPool: self.config.requestCompressionPool(),
                    compressionMinBytes: self.config.compressionMinBytes
                )
            },
            streamResultFunc: { result in
                switch result {
                case .headers(let headers):
                    responseHeaders = headers
                    return result

                case .message(let data):
                    do {
                        let responseCompressionPool = responseHeaders?[
                            HeaderConstants.connectStreamingContentEncoding
                        ]?.first.flatMap { self.config.compressionPools[$0] }
                        let (headerByte, message) = try Envelope.unpackMessage(
                            data, compressionPool: responseCompressionPool
                        )
                        let isEndStream = 0b00000010 & headerByte != 0
                        if isEndStream {
                            // Expect a valid Connect end stream response, which can simply be {}.
                            // https://connect.build/docs/protocol#error-end-stream
                            let response = try JSONDecoder().decode(
                                ConnectEndStreamResponse.self, from: message
                            )
                            return .complete(
                                code: response.error?.code ?? .ok,
                                error: response.error,
                                trailers: response.metadata
                            )
                        } else {
                            return .message(message)
                        }
                    } catch let error {
                        // TODO: Close the stream here?
                        return .complete(code: .unknown, error: error, trailers: nil)
                    }

                case .complete(let code, let error, let trailers):
                    if code != .ok && error == nil {
                        return .complete(
                            code: code,
                            error: ConnectError.from(
                                code: code,
                                headers: responseHeaders ?? [:],
                                source: nil
                            ),
                            trailers: trailers
                        )
                    } else {
                        return result
                    }
                }
            }
        )
    }
}
