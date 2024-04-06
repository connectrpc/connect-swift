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
        idempotencyLevel: IdempotencyLevel,
        request: Input,
        headers: Headers,
        completion: @escaping @Sendable (ResponseMessage<Output>) -> Void
    ) -> Cancelable {
        let cancelation = Locked<(cancelable: Cancelable?, isCancelled: Bool)>((nil, false))
        let config = self.config
        var headers = headers
        headers[HeaderConstants.contentType] = ["application/\(config.codec.name())"]
        let request = HTTPRequest<Input>(
            url: config.createURL(forPath: path),
            headers: headers,
            message: request,
            method: .post,
            trailers: nil,
            idempotencyLevel: idempotencyLevel
        )
        let interceptorChain = self.config.createUnaryInterceptorChain()
        interceptorChain.executeLinkedInterceptorsAndStopOnFailure(
            interceptorChain.interceptors.map { $0.handleUnaryRequest },
            firstInFirstOut: true,
            initial: request,
            transform: { intercepted, proceed in
                do {
                    let data: Data
                    if config.unaryGET.isEnabled && intercepted.idempotencyLevel == .noSideEffects {
                        data = try config.codec.deterministicallySerialize(
                            message: intercepted.message
                        )
                    } else {
                        data = try config.codec.serialize(message: intercepted.message)
                    }
                    proceed(.success(HTTPRequest<Data?>(
                        url: intercepted.url,
                        headers: intercepted.headers,
                        message: data,
                        method: intercepted.method,
                        trailers: intercepted.trailers,
                        idempotencyLevel: intercepted.idempotencyLevel
                    )))
                } catch let error {
                    proceed(.failure(ConnectError(
                        code: .unknown, message: "request serialization failed",
                        exception: error, details: [], metadata: [:]
                    )))
                }
            },
            then: interceptorChain.interceptors.map { $0.handleUnaryRawRequest },
            finish: { interceptedResult in
                cancelation.perform { cancelation in
                    if cancelation.isCancelled {
                        // If the caller cancelled the request while it was being processed
                        // by interceptors, don't send the request.
                        return
                    }

                    let interceptedRequest: HTTPRequest<Data?>
                    switch interceptedResult {
                    case .success(let value):
                        interceptedRequest = value
                    case .failure(let error):
                        completion(ResponseMessage(result: .failure(error)))
                        return
                    }

                    cancelation.cancelable = self.httpClient.unary(
                        request: interceptedRequest,
                        onMetrics: { metrics in
                            interceptorChain.executeInterceptors(
                                interceptorChain.interceptors.map { $0.handleResponseMetrics },
                                firstInFirstOut: false,
                                initial: metrics,
                                finish: { _ in }
                            )
                        },
                        onResponse: { interceptedResponse in
                            interceptorChain.executeLinkedInterceptors(
                                interceptorChain.interceptors.map { $0.handleUnaryRawResponse },
                                firstInFirstOut: false,
                                initial: interceptedResponse,
                                transform: { response, proceed in
                                    proceed(ResponseMessage<Output>(
                                        response: response, codec: config.codec
                                    ))
                                },
                                then: interceptorChain.interceptors.map { $0.handleUnaryResponse },
                                finish: completion
                            )
                        }
                    )
                }
            }
        )
        return Cancelable {
            cancelation.perform { cancelation in
                cancelation.cancelable?.cancel()
                cancelation = (cancelable: nil, isCancelled: true)
            }
        }
    }

    public func bidirectionalStream<
        Input: ProtobufMessage, Output: ProtobufMessage
    >(
        path: String,
        headers: Headers,
        onResult: @escaping @Sendable (StreamResult<Output>) -> Void
    ) -> any BidirectionalStreamInterface<Input> {
        return BidirectionalStream(requestCallbacks: self.createRequestCallbacks(
            path: path, headers: headers, onResult: onResult
        ))
    }

    public func clientOnlyStream<
        Input: ProtobufMessage, Output: ProtobufMessage
    >(
        path: String,
        headers: Headers,
        onResult: @escaping @Sendable (StreamResult<Output>) -> Void
    ) -> any ClientOnlyStreamInterface<Input> {
        return BidirectionalStream(requestCallbacks: self.createRequestCallbacks(
            path: path, headers: headers, onResult: onResult
        ))
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
            )
        ))
    }

    // MARK: - Async/await

    @available(iOS 13, *)
    public func unary<Input: ProtobufMessage, Output: ProtobufMessage>(
        path: String,
        idempotencyLevel: IdempotencyLevel,
        request: Input,
        headers: Headers
    ) async -> ResponseMessage<Output> {
        return await UnaryAsyncWrapper { completion in
            self.unary(
                path: path, idempotencyLevel: idempotencyLevel, request: request,
                headers: headers, completion: completion
            )
        }.send()
    }

    @available(iOS 13, *)
    public func bidirectionalStream<Input: ProtobufMessage, Output: ProtobufMessage>(
        path: String,
        headers: Headers
    ) -> any BidirectionalAsyncStreamInterface<Input, Output> {
        let bidirectionalAsync = BidirectionalAsyncStream<Input, Output>()
        let callbacks: RequestCallbacks<Input> = self.createRequestCallbacks(
            path: path, headers: headers, onResult: { bidirectionalAsync.receive($0) }
        )
        return bidirectionalAsync.configureForSending(with: callbacks)
    }

    @available(iOS 13, *)
    public func clientOnlyStream<Input: ProtobufMessage, Output: ProtobufMessage>(
        path: String,
        headers: Headers
    ) -> any ClientOnlyAsyncStreamInterface<Input, Output> {
        let bidirectionalAsync = BidirectionalAsyncStream<Input, Output>()
        let callbacks: RequestCallbacks<Input> = self.createRequestCallbacks(
            path: path, headers: headers, onResult: { bidirectionalAsync.receive($0) }
        )
        return bidirectionalAsync.configureForSending(with: callbacks)
    }

    @available(iOS 13, *)
    public func serverOnlyStream<Input: ProtobufMessage, Output: ProtobufMessage>(
        path: String,
        headers: Headers
    ) -> any ServerOnlyAsyncStreamInterface<Input, Output> {
        let bidirectionalAsync = BidirectionalAsyncStream<Input, Output>()
        let callbacks: RequestCallbacks<Input> = self.createRequestCallbacks(
            path: path, headers: headers, onResult: { bidirectionalAsync.receive($0) }
        )
        return ServerOnlyAsyncStream(
            bidirectionalStream: bidirectionalAsync.configureForSending(with: callbacks)
        )
    }

    // MARK: - Private

    private func createRequestCallbacks<Input: ProtobufMessage, Output: ProtobufMessage>(
        path: String,
        headers: Headers,
        onResult: @escaping @Sendable (StreamResult<Output>) -> Void
    ) -> RequestCallbacks<Input> {
        let codec = self.config.codec
        let responseBuffer = Locked(Data())
        let hasCompleted = Locked(false)
        let interceptorChain = self.config.createStreamInterceptorChain()
        let onResult: @Sendable (StreamResult<Output>) -> Void = { output in
            if case .complete = output {
                hasCompleted.value = true
            }
            onResult(output)
        }
        let responseCallbacks = ResponseCallbacks(
            receiveResponseHeaders: { responseHeaders in
                interceptorChain.executeLinkedInterceptors(
                    interceptorChain.interceptors.map { $0.handleStreamRawResult },
                    firstInFirstOut: false,
                    initial: .headers(responseHeaders),
                    transform: { interceptedResult, proceed in
                        if let typedResult = interceptedResult.toTyped(Output.self, using: codec) {
                            proceed(typedResult)
                        }
                    },
                    then: interceptorChain.interceptors.map { $0.handleStreamResult },
                    finish: onResult
                )
            },
            receiveResponseData: { data in
                responseBuffer.perform { responseBuffer in
                    // Handle cases where multiple messages are received in a single chunk.
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

                        interceptorChain.executeLinkedInterceptors(
                            interceptorChain.interceptors.map { $0.handleStreamRawResult },
                            firstInFirstOut: false,
                            initial: .message(responseBuffer.prefix(prefixedMessageLength)),
                            transform: { interceptedResult, proceed in
                                if let typedResult = interceptedResult.toTyped(
                                    Output.self, using: codec
                                ) {
                                    proceed(typedResult)
                                }
                            },
                            then: interceptorChain.interceptors.map { $0.handleStreamResult },
                            finish: onResult
                        )
                        responseBuffer = Data(responseBuffer.suffix(from: prefixedMessageLength))
                    }
                }
            },
            receiveResponseMetrics: { metrics in
                interceptorChain.executeInterceptors(
                    interceptorChain.interceptors.map { $0.handleResponseMetrics },
                    firstInFirstOut: false,
                    initial: metrics,
                    finish: { _ in }
                )
            },
            receiveClose: { code, trailers, error in
                if hasCompleted.value {
                    return
                }
                interceptorChain.executeLinkedInterceptors(
                    interceptorChain.interceptors.map { $0.handleStreamRawResult },
                    firstInFirstOut: false,
                    initial: .complete(code: code, error: error, trailers: trailers),
                    transform: { interceptedResult, proceed in
                        if let typedResult = interceptedResult.toTyped(Output.self, using: codec) {
                            proceed(typedResult)
                        }
                    },
                    then: interceptorChain.interceptors.map { $0.handleStreamResult },
                    finish: onResult
                )
            }
        )

        let pendingRequestCallbacks = PendingRequestCallbacks()
        var headers = headers
        headers[HeaderConstants.contentType] = ["application/connect+\(codec.name())"]
        let request = HTTPRequest<Void>(
            url: config.createURL(forPath: path),
            headers: headers,
            message: (),
            method: .post,
            trailers: nil,
            idempotencyLevel: .unknown
        )
        interceptorChain.executeInterceptorsAndStopOnFailure(
            interceptorChain.interceptors.map { $0.handleStreamStart },
            firstInFirstOut: true,
            initial: request,
            finish: { result in
                switch result {
                case .success(let interceptedRequest):
                    pendingRequestCallbacks.setCallbacks(self.httpClient.stream(
                        request: HTTPRequest(
                            url: interceptedRequest.url,
                            headers: interceptedRequest.headers,
                            message: nil, // Message is void on stream creation.
                            method: interceptedRequest.method,
                            trailers: interceptedRequest.trailers,
                            idempotencyLevel: interceptedRequest.idempotencyLevel
                        ),
                        responseCallbacks: responseCallbacks
                    ))
                case .failure(let error):
                    hasCompleted.value = true
                    onResult(.complete(code: error.code, error: error, trailers: error.metadata))
                }
            }
        )
        return RequestCallbacks<Input>(cancel: {
            pendingRequestCallbacks.enqueue { requestCallbacks in
                requestCallbacks.cancel()
            }
        }, sendData: { requestMessage in
            // Wait for the stream to be established before sending data.
            pendingRequestCallbacks.enqueue { requestCallbacks in
                interceptorChain.executeLinkedInterceptors(
                    interceptorChain.interceptors.map { $0.handleStreamInput },
                    firstInFirstOut: true,
                    initial: requestMessage,
                    transform: { interceptedMessage, proceed in
                        do {
                            proceed(try codec.serialize(message: interceptedMessage))
                        } catch let error {
                            os_log(
                                .error,
                                "Failed to send request message which could not be serialized: %@",
                                error.localizedDescription
                            )
                        }
                    },
                    then: interceptorChain.interceptors.map { $0.handleStreamRawInput },
                    finish: requestCallbacks.sendData
                )
            }
        }, sendClose: {
            pendingRequestCallbacks.enqueue { requestCallbacks in
                requestCallbacks.sendClose()
            }
        })
    }
}

private final class PendingRequestCallbacks: @unchecked Sendable {
    private let lock = Lock()
    private var callbacks: RequestCallbacks<Data>?
    private var queue = [(RequestCallbacks<Data>) -> Void]()

    func setCallbacks(_ callbacks: RequestCallbacks<Data>) {
        self.lock.perform {
            self.callbacks = callbacks
            for action in self.queue {
                action(callbacks)
            }
            self.queue = []
        }
    }

    func enqueue(_ action: @escaping (RequestCallbacks<Data>) -> Void) {
        self.lock.perform {
            if let callbacks = self.callbacks {
                action(callbacks)
            } else {
                self.queue.append(action)
            }
        }
    }
}

private extension ResponseMessage where Output: ProtobufMessage {
    init(response: HTTPResponse, codec: Codec) {
        if response.code != .ok {
            let error = (response.error as? ConnectError)
            ?? ConnectError.from(
                code: response.code,
                headers: response.headers,
                trailers: response.trailers,
                source: response.message
            )
            self.init(
                code: response.code,
                headers: response.headers,
                result: .failure(error),
                trailers: response.trailers
            )
        } else if let message = response.message {
            do {
                self.init(
                    code: response.code,
                    headers: response.headers,
                    result: .success(try codec.deserialize(source: message)),
                    trailers: response.trailers
                )
            } catch let error {
                self.init(
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
            self.init(
                code: response.code,
                headers: response.headers,
                result: .success(.init()),
                trailers: response.trailers
            )
        }
    }
}

private extension StreamResult<Data> {
    func toTyped<Message: ProtobufMessage>(
        _ type: Message.Type, using codec: Codec
    ) -> StreamResult<Message>? {
        switch self {
        case .complete(let code, let error, let trailers):
            return .complete(code: code, error: error, trailers: trailers)
        case .headers(let headers):
            return .headers(headers)
        case .message(let data):
            do {
                return .message(try codec.deserialize(source: data))
            } catch let error {
                os_log(
                    .error,
                    "Stream result failed to deserialize: %@",
                    error.localizedDescription
                )
                return nil
            }
        }
    }
}
