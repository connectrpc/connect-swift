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
import os.log
import SwiftProtobuf

/// Concrete implementation of the `ProtocolClientInterface`.
public final class ProtocolClient: Sendable {
    private let config: ProtocolClientConfig
    private let httpClient: HTTPClientInterface

    /// Designated initializer.
    ///
    /// - parameter httpClient: The HTTP client to use for sending requests and starting streams.
    /// - parameter config: The configuration to use for requests and streams.
    public init(
        httpClient: HTTPClientInterface = URLSessionHTTPClient(),
        config: ProtocolClientConfig
    ) {
        self.httpClient = httpClient
        self.config = config
    }
}

extension ProtocolClient: ProtocolClientInterface {
    // MARK: - Callbacks

    @discardableResult
    public func unary<Input: ProtobufMessage, Output: ProtobufMessage>(
        path: String,
        request: Input,
        headers: Headers,
        completion: @escaping @Sendable (ResponseMessage<Output>) -> Void
    ) -> Cancelable {
        let codec = self.config.codec
        let data: Data
        do {
            data = try codec.serialize(message: request)
        } catch let error {
            completion(ResponseMessage(
                code: .unknown,
                result: .failure(ConnectError(
                    code: .unknown, message: "request serialization failed", exception: error,
                    details: [], metadata: [:]
                ))
            ))
            return Cancelable(cancel: {})
        }

        let interceptorChain = self.config.createInterceptorChain()
        let request = HTTPRequest(
            url: URL(string: path, relativeTo: URL(string: self.config.host))!,
            contentType: "application/\(codec.name())",
            headers: headers,
            message: data,
            trailers: nil
        )
        let cancelable = Locked<Cancelable?>(nil)
        let finishProcessingResponse: (HTTPResponse) -> Void = { response in
            let responseMessage: ResponseMessage<Output>
            if response.code != .ok {
                let error = (response.error as? ConnectError)
                ?? ConnectError.from(
                    code: response.code,
                    headers: response.headers,
                    source: response.message
                )
                responseMessage = ResponseMessage(
                    code: response.code,
                    headers: response.headers,
                    result: .failure(error),
                    trailers: response.trailers
                )
            } else if let message = response.message {
                do {
                    responseMessage = ResponseMessage(
                        code: response.code,
                        headers: response.headers,
                        result: .success(try codec.deserialize(source: message)),
                        trailers: response.trailers
                    )
                } catch let error {
                    responseMessage = ResponseMessage(
                        code: response.code,
                        headers: response.headers,
                        result: .failure(ConnectError(
                            code: response.code, message: nil, exception: error,
                            details: [], metadata: response.headers
                        )),
                        trailers: response.trailers
                    )
                }
            } else {
                responseMessage = ResponseMessage(
                    code: response.code,
                    headers: response.headers,
                    result: .success(.init()),
                    trailers: response.trailers
                )
            }
            completion(responseMessage)
        }
        interceptorChain.execute(
            interceptorChain.unary.map(\.requestFunction),
            initial: request,
            finish: { interceptedRequest in
                cancelable.value = self.httpClient.unary(
                    request: interceptedRequest,
                    onMetrics: { metrics in
                        interceptorChain.execute(
                            interceptorChain.unary.reversed().map(\.responseMetricsFunction),
                            initial: metrics, 
                            finish: { _ in }
                        )
                    },
                    onResponse: { response in
                        interceptorChain.execute(
                            interceptorChain.unary.reversed().map(\.responseFunction),
                            initial: response,
                            finish: finishProcessingResponse
                        )
                    }
                )
            }
        )
        return Cancelable(cancel: { cancelable.value?.cancel() })
    }

    public func bidirectionalStream<
        Input: ProtobufMessage, Output: ProtobufMessage
    >(
        path: String,
        headers: Headers,
        onResult: @escaping @Sendable (StreamResult<Output>) -> Void
    ) -> any BidirectionalStreamInterface<Input> {
        return BidirectionalStream(
            requestCallbacks: self.createRequestCallbacks(
                path: path, headers: headers, onResult: onResult
            ),
            codec: self.config.codec
        )
    }

    public func clientOnlyStream<
        Input: ProtobufMessage, Output: ProtobufMessage
    >(
        path: String,
        headers: Headers,
        onResult: @escaping @Sendable (StreamResult<Output>) -> Void
    ) -> any ClientOnlyStreamInterface<Input> {
        return BidirectionalStream(
            requestCallbacks: self.createRequestCallbacks(
                path: path, headers: headers, onResult: onResult
            ),
            codec: self.config.codec
        )
    }

    public func serverOnlyStream<
        Input: ProtobufMessage, Output: ProtobufMessage
    >(
        path: String,
        headers: Headers,
        onResult: @escaping @Sendable (StreamResult<Output>) -> Void
    ) -> any ServerOnlyStreamInterface<Input> {
        return ServerOnlyStream(bidirectionalStream: BidirectionalStream(
            requestCallbacks: self.createRequestCallbacks(
                path: path, headers: headers, onResult: onResult
            ),
            codec: self.config.codec
        ))
    }

    // MARK: - Async/await

    @available(iOS 13, *)
    public func unary<Input: ProtobufMessage, Output: ProtobufMessage>(
        path: String,
        request: Input,
        headers: Headers
    ) async -> ResponseMessage<Output> {
        return await UnaryAsyncWrapper { completion in
            self.unary(path: path, request: request, headers: headers, completion: completion)
        }.send()
    }

    @available(iOS 13, *)
    public func bidirectionalStream<Input: ProtobufMessage, Output: ProtobufMessage>(
        path: String,
        headers: Headers
    ) -> any BidirectionalAsyncStreamInterface<Input, Output> {
        let bidirectionalAsync = BidirectionalAsyncStream<Input, Output>(codec: self.config.codec)
        let callbacks = self.createRequestCallbacks(
            path: path, headers: headers, onResult: { bidirectionalAsync.receive($0) }
        )
        return bidirectionalAsync.configureForSending(with: callbacks)
    }

    @available(iOS 13, *)
    public func clientOnlyStream<Input: ProtobufMessage, Output: ProtobufMessage>(
        path: String,
        headers: Headers
    ) -> any ClientOnlyAsyncStreamInterface<Input, Output> {
        let bidirectionalAsync = BidirectionalAsyncStream<Input, Output>(codec: self.config.codec)
        let callbacks = self.createRequestCallbacks(
            path: path, headers: headers, onResult: { bidirectionalAsync.receive($0) }
        )
        return bidirectionalAsync.configureForSending(with: callbacks)
    }

    @available(iOS 13, *)
    public func serverOnlyStream<Input: ProtobufMessage, Output: ProtobufMessage>(
        path: String,
        headers: Headers
    ) -> any ServerOnlyAsyncStreamInterface<Input, Output> {
        let bidirectionalAsync = BidirectionalAsyncStream<Input, Output>(codec: self.config.codec)
        let callbacks = self.createRequestCallbacks(
            path: path, headers: headers, onResult: { bidirectionalAsync.receive($0) }
        )
        return ServerOnlyAsyncStream(
            bidirectionalStream: bidirectionalAsync.configureForSending(with: callbacks)
        )
    }

    // MARK: - Private

    private func createRequestCallbacks<Output: ProtobufMessage>(
        path: String,
        headers: Headers,
        onResult: @escaping @Sendable (StreamResult<Output>) -> Void
    ) -> RequestCallbacks {
        let codec = self.config.codec
        let responseBuffer = Locked(Data())
        let hasCompleted = Locked(false)
        let interceptorChain = self.config.createInterceptorChain()

        let finishHandlingResult: (StreamResult<Data>) -> Void = { result in
            do {
                if case .complete = result {
                    hasCompleted.value = true
                }
                onResult(try result.toTypedResult(using: codec))
            } catch let error {
                // TODO: Should we terminate the stream here?
                os_log(
                    .error,
                    "Failed to deserialize stream result - dropping result: %@",
                    error.localizedDescription
                )
            }
        }
        let responseCallbacks = ResponseCallbacks(
            receiveResponseHeaders: { responseHeaders in
                interceptorChain.execute(
                    interceptorChain.stream.reversed().map(\.streamResultFunction),
                    initial: .headers(responseHeaders),
                    finish: finishHandlingResult
                )
            },
            receiveResponseData: { data in
                // Repeating handles cases where multiple messages are received in a single chunk.
                responseBuffer.perform { responseBuffer in
                    responseBuffer += data
                    while true {
                        let messageLength = Envelope.messageLength(forPackedData: responseBuffer)
                        if messageLength < 0 {
                            return
                        }

                        let prefixedMessageLength = Envelope.prefixLength + messageLength
                        guard responseBuffer.count >= prefixedMessageLength else {
                            return
                        }

                        interceptorChain.execute(
                            interceptorChain.stream.reversed().map(\.streamResultFunction),
                            initial: .message(responseBuffer.prefix(prefixedMessageLength)),
                            finish: finishHandlingResult
                        )
                        responseBuffer = Data(responseBuffer.suffix(from: prefixedMessageLength))
                    }
                }
            },
            receiveClose: { code, trailers, error in
                if !hasCompleted.value {
                    interceptorChain.execute(
                        interceptorChain.stream.reversed().map(\.streamResultFunction),
                        initial: .complete(
                            code: code,
                            error: error,
                            trailers: trailers
                        ),
                        finish: finishHandlingResult
                    )
                }
            }
        )

        let requestCallbacksQueue = RequestCallbacksQueue()
        let request = HTTPRequest(
            url: URL(string: path, relativeTo: URL(string: self.config.host))!,
            contentType: "application/connect+\(codec.name())",
            headers: headers,
            message: nil,
            trailers: nil
        )
        interceptorChain.execute(
            interceptorChain.stream.map(\.requestFunction),
            initial: request,
            finish: { interceptedRequest in
                requestCallbacksQueue.setCallbacks(self.httpClient.stream(
                    request: interceptedRequest,
                    responseCallbacks: responseCallbacks
                ))
            }
        )
        return RequestCallbacks { data in
            interceptorChain.execute(
                interceptorChain.stream.map(\.requestDataFunction),
                initial: data,
                finish: { interceptedData in
                    requestCallbacksQueue.enqueue { requestCallbacks in
                        requestCallbacks.sendData(interceptedData)
                    }
                }
            )
        } sendClose: {
            requestCallbacksQueue.enqueue { requestCallbacks in
                requestCallbacks.sendClose()
            }
        }
    }
}

private extension StreamResult<Data> {
    func toTypedResult<M: ProtobufMessage>(using codec: Codec) throws -> StreamResult<M> {
        switch self {
        case .complete(let code, let error, let trailers):
            return .complete(code: code, error: error, trailers: trailers)
        case .headers(let headers):
            return .headers(headers)
        case .message(let data):
            return .message(try codec.deserialize(source: data))
        }
    }
}

private final class RequestCallbacksQueue {
    private let lock = Lock()
    private var callbacks: RequestCallbacks?
    private var queue = [(RequestCallbacks) -> Void]()

    func setCallbacks(_ callbacks: RequestCallbacks) {
        self.lock.perform {
            self.callbacks = callbacks
            for action in self.queue {
                action(callbacks)
            }
            self.queue = []
        }
    }

    func enqueue(_ action: @escaping (RequestCallbacks) -> Void) {
        self.lock.perform {
            if let callbacks = self.callbacks {
                action(callbacks)
            } else {
                self.queue.append(action)
            }
        }
    }
}
