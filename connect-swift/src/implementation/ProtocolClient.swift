import Foundation
import os.log
import Wire

/// Concrete implementation of the `ProtocolClientInterface`.
public final class ProtocolClient {
    private let config: ProtocolClientConfig

    /// Instantiate a new client.
    ///
    /// - parameter target: The target host (e.g., https://buf.build).
    /// - parameter httpClient: HTTP client to use for performing requests.
    /// - parameter options: Series of options with which to configure the client. Identity and gzip
    ///                      compression options are provided by default.
    public init(
        target: String, httpClient: HTTPClientInterface, _ options: ProtocolClientOption...
    ) {
        var config = ProtocolClientConfig(
            target: target, httpClient: httpClient, codec: JSONCodec()
        )
        config = IdentityCompressionOption().apply(config)
        config = GzipCompressionOption().apply(config)
        for option in options {
            config = option.apply(config)
        }
        self.config = config
    }
}

extension ProtocolClient: ProtocolClientInterface {
    public func unary<
        Input: Wire.ProtoEncodable & Swift.Encodable, Output: Wire.ProtoDecodable & Swift.Decodable
    >(
        path: String,
        request: Input,
        headers: Headers,
        completion: @escaping (ResponseMessage<Output>) -> Void
    ) {
        let codec = self.config.codec
        let data: Data
        do {
            data = try codec.serialize(message: request)
        } catch let error {
            completion(ResponseMessage(
                code: .unknown,
                headers: [:],
                message: nil,
                error: ConnectError(
                    code: .unknown, message: "request serialization failed", exception: error,
                    details: [], metadata: [:]
                )
            ))
            return
        }

        let chain = self.config.createUnaryInterceptorChain()
        let url = URL(string: path, relativeTo: URL(string: self.config.target))!
        let request = chain.requestFunction(HTTPRequest(
            target: url,
            contentType: "application/\(codec.name())",
            headers: headers,
            message: data
        ))
        self.config.httpClient.unary(request: request) { response in
            let response = chain.responseFunction(response)
            let responseMessage: ResponseMessage<Output>
            if response.code != .ok {
                let error = (response.error as? ConnectError)
                    ?? ConnectError.from(
                        code: response.code, headers: response.headers, source: response.message
                    )
                responseMessage = ResponseMessage(
                    code: response.code,
                    headers: response.headers,
                    message: nil,
                    error: error
                )
            } else if response.message == nil {
                responseMessage = ResponseMessage(
                    code: response.code,
                    headers: response.headers,
                    message: nil,
                    error: nil
                )
            } else {
                do {
                    responseMessage = ResponseMessage(
                        code: response.code,
                        headers: response.headers,
                        message: try response.message.map(codec.deserialize),
                        error: nil
                    )
                } catch let error {
                    responseMessage = ResponseMessage(
                        code: response.code,
                        headers: response.headers,
                        message: nil,
                        error: ConnectError(
                            code: response.code, message: nil, exception: error,
                            details: [], metadata: response.headers
                        )
                    )
                }
            }
            completion(responseMessage)
        }
    }

    public func bidirectionalStream<
        Input: Wire.ProtoEncodable & Swift.Encodable, Output: Wire.ProtoDecodable & Swift.Decodable
    >(
        path: String,
        headers: Headers,
        onResult: @escaping (StreamResult<Output>) -> Void
    ) -> any BidirectionalStreamInterface<Input> {
        return self.createBidirectionalStream(
            path: path, headers: headers, onResult: onResult
        )
    }

    public func clientOnlyStream<
        Input: Wire.ProtoEncodable & Swift.Encodable, Output: Wire.ProtoDecodable & Swift.Decodable
    >(
        path: String,
        headers: Headers,
        onResult: @escaping (StreamResult<Output>) -> Void
    ) -> any ClientOnlyStreamInterface<Input> {
        return ClientOnlyStream(bidirectionalStream: self.createBidirectionalStream(
            path: path, headers: headers, onResult: onResult
        ))
    }

    public func serverOnlyStream<
        Input: Wire.ProtoEncodable & Swift.Encodable, Output: Wire.ProtoDecodable & Swift.Decodable
    >(
        path: String,
        headers: Headers,
        onResult: @escaping (StreamResult<Output>) -> Void
    ) -> any ServerOnlyStreamInterface<Input> {
        return ServerOnlyStream(bidirectionalStream: self.createBidirectionalStream(
            path: path, headers: headers, onResult: onResult
        ))
    }

    // MARK: - Private

    private func createBidirectionalStream<
        Input: Wire.ProtoEncodable & Swift.Encodable, Output: Wire.ProtoDecodable & Swift.Decodable
    >(
        path: String,
        headers: Headers,
        onResult: @escaping (StreamResult<Output>) -> Void
    ) -> BidirectionalStream<Input> {
        let codec = self.config.codec
        let chain = self.config.createStreamingInterceptorChain()
        let url = URL(string: path, relativeTo: URL(string: self.config.target))!
        let request = chain.requestFunction(HTTPRequest(
            target: url,
            contentType: "application/connect+\(codec.name())",
            headers: headers,
            message: nil
        ))

        let interceptAndHandleResult: (StreamResult<Data>) -> Void = { streamResult in
            do {
                let interceptedResult = chain.streamResultFunc(streamResult)
                onResult(try interceptedResult.toTypedResult(using: codec))
            } catch let error {
                // TODO: Should we terminate the stream here?
                os_log(
                    .error,
                    "Failed to deserialize stream result - dropping result: %@",
                    error.localizedDescription
                )
            }
        }
        var responseBuffer = Data()
        let responseCallbacks = ResponseCallbacks(
            receiveResponseHeaders: { interceptAndHandleResult(.headers($0)) },
            receiveResponseData: { responseChunk in
                // Repeating handles cases where multiple messages are received in a single chunk.
                responseBuffer += responseChunk
                while true {
                    let messageLength = Envelope.messageLength(forPackedData: responseBuffer)
                    if messageLength < 0 {
                        return
                    }

                    let prefixedMessageLength = Envelope.prefixLength + messageLength
                    guard responseBuffer.count >= prefixedMessageLength else {
                        return
                    }

                    // TODO: Document buffering behavior requirements in interface declaration
                    interceptAndHandleResult(.message(responseBuffer.prefix(prefixedMessageLength)))
                    responseBuffer = Data(responseBuffer.suffix(from: prefixedMessageLength))
                }
            },
            receiveClose: { error in
                if let error = error {
                    // Only pass the result through as completion if there is an error.
                    // An example of this codepath would be the client disconnecting mid-stream.
                    // The happy path is usually determined by "end stream" flags in the
                    // response body.
                    interceptAndHandleResult(.complete(error: error, trailers: nil))
                }
            }
        )
        let httpRequestCallbacks = self.config.httpClient.stream(
            request: request,
            responseCallbacks: responseCallbacks
        )
        return BidirectionalStream(
            // Wrap the request data callback to invoke the interceptor chain.
            requestCallbacks: RequestCallbacks(
                sendData: { httpRequestCallbacks.sendData(chain.requestDataFunction($0)) },
                sendClose: httpRequestCallbacks.sendClose
            ),
            codec: codec
        )
    }
}

private extension StreamResult<Data> {
    func toTypedResult<Output: Wire.ProtoDecodable & Swift.Decodable>(using codec: Codec)
        throws -> StreamResult<Output>
    {
        switch self {
        case .complete(let error, let trailers):
            return .complete(error: error, trailers: trailers)
        case .headers(let headers):
            return .headers(headers)
        case .message(let data):
            return .message(try codec.deserialize(source: data))
        }
    }
}
