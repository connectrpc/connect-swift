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
        let interceptorChain = self.config.createUnaryInterceptorChain()
        let request = interceptorChain.executeInterceptors(
            interceptorChain.interceptors.map { $0.willSendMessage },
            firstInFirstOut: true,
            initial: request
        )

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
            return Cancelable {}
        }

        let httpRequest = HTTPRequest(
            url: URL(string: path, relativeTo: URL(string: self.config.host))!,
            contentType: "application/\(codec.name())",
            headers: headers,
            message: data,
            trailers: nil
        )
        let cancelation = Locked<(cancelable: Cancelable?, isCancelled: Bool)>((nil, false))
        let finishHandlingResponse: @Sendable (HTTPResponse) -> Void = { response in
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
                        result: .success(interceptorChain.executeInterceptors(
                            interceptorChain.interceptors.map { $0.didReceiveMessage },
                            firstInFirstOut: false,
                            initial: try codec.deserialize(source: message)
                        )),
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
        interceptorChain.executeInterceptorsAndStopOnFailure(
            interceptorChain.interceptors.map { $0.handleUnaryRequest },
            firstInFirstOut: true,
            initial: httpRequest,
            finish: { result in
                cancelation.perform { cancelation in
                    if cancelation.isCancelled {
                        // If the caller cancelled the request while it was being processed
                        // by interceptors, don't send the request.
                        return
                    }

                    let interceptedRequest: HTTPRequest
                    switch result {
                    case .success(let value):
                        interceptedRequest = value
                    case .failure(let error):
                        completion(.init(result: .failure(error)))
                        return
                    }

                    cancelation.cancelable = self.httpClient.unary(
                        request: interceptedRequest,
                        onMetrics: { metrics in
                            interceptorChain.executeInterceptors(
                                interceptorChain.interceptors.map { $0.handleUnaryResponseMetrics },
                                firstInFirstOut: false,
                                initial: metrics,
                                finish: { _ in }
                            )
                        },
                        onResponse: { response in
                            interceptorChain.executeInterceptors(
                                interceptorChain.interceptors.map { $0.handleUnaryResponse },
                                firstInFirstOut: false,
                                initial: response,
                                finish: finishHandlingResponse
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
        let finishHandlingResult: @Sendable (StreamResult<Data>) -> Void = { result in
            do {
                switch result {
                case .headers(let headers):
                    onResult(.headers(headers))
                case .message(let data):
                    let message = interceptorChain.executeInterceptors(
                        interceptorChain.interceptors.map { $0.didReceiveMessage },
                        firstInFirstOut: false,
                        initial: try codec.deserialize(source: data) as Output
                    )
                    onResult(.message(message))
                case .complete(let code, let error, let trailers):
                    hasCompleted.value = true
                    onResult(.complete(code: code, error: error, trailers: trailers))
                }

            } catch let error {
                os_log(
                    .error,
                    "Dropping stream result which failed to deserialize: %@",
                    error.localizedDescription
                )
            }
        }
        let responseCallbacks = ResponseCallbacks(
            receiveResponseHeaders: { responseHeaders in
                interceptorChain.executeInterceptors(
                    interceptorChain.interceptors.map { $0.handleStreamResult },
                    firstInFirstOut: false,
                    initial: .headers(responseHeaders),
                    finish: finishHandlingResult
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

                        interceptorChain.executeInterceptors(
                            interceptorChain.interceptors.map { $0.handleStreamResult },
                            firstInFirstOut: false,
                            initial: .message(responseBuffer.prefix(prefixedMessageLength)),
                            finish: finishHandlingResult
                        )
                        responseBuffer = Data(responseBuffer.suffix(from: prefixedMessageLength))
                    }
                }
            },
            receiveClose: { code, trailers, error in
                if hasCompleted.value {
                    return
                }
                interceptorChain.executeInterceptors(
                    interceptorChain.interceptors.map { $0.handleStreamResult },
                    firstInFirstOut: false,
                    initial: .complete(code: code, error: error, trailers: trailers),
                    finish: finishHandlingResult
                )
            }
        )

        let pendingRequestCallbacks = PendingRequestCallbacks()
        let request = HTTPRequest(
            url: URL(string: path, relativeTo: URL(string: self.config.host))!,
            contentType: "application/connect+\(codec.name())",
            headers: headers,
            message: nil,
            trailers: nil
        )
        interceptorChain.executeInterceptorsAndStopOnFailure(
            interceptorChain.interceptors.map { $0.handleStreamRequest },
            firstInFirstOut: true,
            initial: request,
            finish: { result in
                switch result {
                case .success(let interceptedRequest):
                    pendingRequestCallbacks.setCallbacks(self.httpClient.stream(
                        request: interceptedRequest,
                        responseCallbacks: responseCallbacks
                    ))
                case .failure(let error):
                    hasCompleted.value = true
                    onResult(.complete(code: error.code, error: error, trailers: error.metadata))
                }
            }
        )
        return RequestCallbacks<Input> { requestMessage in
            // Wait for the stream to be established before sending data.
            pendingRequestCallbacks.enqueue { requestCallbacks in
                let interceptedMessage = interceptorChain.executeInterceptors(
                    interceptorChain.interceptors.map { $0.willSendMessage },
                    firstInFirstOut: true,
                    initial: requestMessage
                )
                do {
                    interceptorChain.executeInterceptors(
                        interceptorChain.interceptors.map { $0.handleStreamRequestData },
                        firstInFirstOut: true,
                        initial: try codec.serialize(message: interceptedMessage),
                        finish: requestCallbacks.sendData
                    )
                } catch let error {
                    os_log(
                        .error,
                        "Failed to send request message which could not be serialized: %@",
                        error.localizedDescription
                    )
                }
            }
        } sendClose: {
            pendingRequestCallbacks.enqueue { requestCallbacks in
                requestCallbacks.sendClose()
            }
        }
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
