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
        let task = Task {
            let response: ResponseMessage<Output> = await self.unary(
                path: path, idempotencyLevel: idempotencyLevel, request: request, headers: headers
            )
            // Cancelation drops the completion, matching the closure-based implementation this
            // replaced.
            // TODO: Deliver a `.canceled` `ResponseMessage` instead.
            guard !Task.isCancelled else {
                return
            }

            completion(response)
        }
        return Cancelable { task.cancel() }
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
        let clientOnly = ClientOnlyStream<Input, Output>(onResult: onResult)
        let callbacks: RequestCallbacks<Input> = self.createRequestCallbacks(
            path: path, headers: headers, onResult: { clientOnly.handleResultFromServer($0) }
        )
        return clientOnly.configureForSending(with: callbacks)
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

    public func unary<Input: ProtobufMessage, Output: ProtobufMessage>(
        path: String,
        idempotencyLevel: IdempotencyLevel,
        request: Input,
        headers: Headers
    ) async -> ResponseMessage<Output> {
        let config = self.config
        var headers = headers
        headers[HeaderConstants.contentType] = ["application/\(config.codec.name())"]
        let interceptorChain = config.createUnaryInterceptorChain()
        let httpRequest = HTTPRequest<Input>(
            url: config.createURL(forPath: path),
            headers: headers,
            message: request,
            method: .post,
            trailers: nil,
            idempotencyLevel: idempotencyLevel
        )

        do {
            let intercepted = try await interceptorChain.executeRequest(httpRequest)
            let serialized = try Self.serialize(intercepted, config: config)
            let interceptedRequest = try await interceptorChain.executeRawRequest(serialized)

            // If the caller canceled the request while it was being processed by interceptors,
            // don't send the request.
            try Task.checkCancellation()

            let sendRequest: @Sendable () async -> HTTPResponse = {
                await self.httpClient.unary(
                    request: interceptedRequest,
                    onMetrics: { metrics in
                        Task { _ = await interceptorChain.executeMetrics(metrics) }
                    }
                )
            }
            let response: HTTPResponse
            if let timeout = config.timeout {
                response = await withDeadline(timeout, operation: sendRequest)
                    ?? Self.deadlineExceededResponse()
            } else {
                response = await sendRequest()
            }
            let interceptedResponse = await interceptorChain.executeRawResponse(response)
            return await interceptorChain.executeResponse(ResponseMessage<Output>(
                response: interceptedResponse, codec: config.codec
            ))
        } catch let error as ConnectError {
            // Matches the closure-based implementation this replaced: a failure originating from
            // the request path is returned directly, without invoking the response interceptors.
            return ResponseMessage(result: .failure(error))
        } catch is CancellationError {
            return ResponseMessage(code: .canceled, result: .failure(.canceled()))
        } catch let error {
            return ResponseMessage(result: .failure(ConnectError(
                code: .unknown, message: "request serialization failed",
                exception: error, details: [], metadata: [:]
            )))
        }
    }

    public func bidirectionalStream<Input: ProtobufMessage, Output: ProtobufMessage>(
        path: String,
        headers: Headers
    ) -> any BidirectionalAsyncStreamInterface<Input, Output> {
        let bidirectionalAsync = BidirectionalAsyncStream<Input, Output>()
        let callbacks: RequestCallbacks<Input> = self.createRequestCallbacks(
            path: path, headers: headers,
            onResult: { bidirectionalAsync.handleResultFromServer($0) }
        )
        return bidirectionalAsync.configureForSending(with: callbacks)
    }

    public func clientOnlyStream<Input: ProtobufMessage, Output: ProtobufMessage>(
        path: String,
        headers: Headers
    ) -> any ClientOnlyAsyncStreamInterface<Input, Output> {
        let bidirectionalAsync = BidirectionalAsyncStream<Input, Output>()
        let clientOnlyAsync = ClientOnlyAsyncStream(bidirectionalStream: bidirectionalAsync)
        let callbacks: RequestCallbacks<Input> = self.createRequestCallbacks(
            path: path, headers: headers, onResult: { clientOnlyAsync.handleResultFromServer($0) }
        )
        bidirectionalAsync.configureForSending(with: callbacks)
        return clientOnlyAsync
    }

    public func serverOnlyStream<Input: ProtobufMessage, Output: ProtobufMessage>(
        path: String,
        headers: Headers
    ) -> any ServerOnlyAsyncStreamInterface<Input, Output> {
        let bidirectionalAsync = BidirectionalAsyncStream<Input, Output>()
        let callbacks: RequestCallbacks<Input> = self.createRequestCallbacks(
            path: path, headers: headers,
            onResult: { bidirectionalAsync.handleResultFromServer($0) }
        )
        return ServerOnlyAsyncStream(
            bidirectionalStream: bidirectionalAsync.configureForSending(with: callbacks)
        )
    }

    // MARK: - Private

    /// Serialize a typed request into its raw form, matching the codec selection rules used for
    /// unary requests (deterministic serialization is required for idempotent GET requests, since
    /// the serialized message is used to build the URL).
    ///
    /// - parameter request: The typed request to serialize.
    /// - parameter config: The configuration providing the codec and unary GET settings.
    /// - returns: The request with its message replaced by serialized data.
    /// - throws: A `ConnectError` with a `.unknown` code if serialization fails.
    private static func serialize<Input: ProtobufMessage>(
        _ request: HTTPRequest<Input>, config: ProtocolClientConfig
    ) throws -> HTTPRequest<Data?> {
        do {
            let data: Data
            if config.unaryGET.isEnabled && request.idempotencyLevel == .noSideEffects {
                data = try config.codec.deterministicallySerialize(message: request.message)
            } else {
                data = try config.codec.serialize(message: request.message)
            }
            return HTTPRequest<Data?>(
                url: request.url,
                headers: request.headers,
                message: data,
                method: request.method,
                trailers: request.trailers,
                idempotencyLevel: request.idempotencyLevel
            )
        } catch let error {
            throw ConnectError(
                code: .unknown, message: "request serialization failed",
                exception: error, details: [], metadata: [:]
            )
        }
    }

    /// The response synthesized when the request's deadline elapses before the server responds.
    ///
    /// Headers and trailers are empty: no response was ever received to carry them. The
    /// closure-based implementation this replaced copied headers from the canceled response, but
    /// both built-in HTTP clients already report those as empty here, so behavior is unchanged.
    private static func deadlineExceededResponse() -> HTTPResponse {
        return HTTPResponse(
            code: .deadlineExceeded,
            headers: [:],
            message: nil,
            trailers: [:],
            error: ConnectError(
                code: .deadlineExceeded,
                message: "request exceeded allowed timeout",
                exception: nil, details: [], metadata: [:]
            ),
            tracingInfo: nil
        )
    }

    private func createRequestCallbacks<Input: ProtobufMessage, Output: ProtobufMessage>(
        path: String,
        headers: Headers,
        onResult: @escaping @Sendable (StreamResult<Output>) -> Void
    ) -> RequestCallbacks<Input> {
        let codec = self.config.codec
        let responseBuffer = Locked(Data())
        let hasCompleted = Locked(false)
        let timeoutTimer = TimeoutTimer(config: self.config)
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

                var code = code
                var error = error
                if code == .canceled && timeoutTimer?.timedOut == true {
                    code = .deadlineExceeded
                    error = ConnectError(
                        code: .deadlineExceeded,
                        message: "request exceeded allowed timeout",
                        exception: nil, details: [], metadata: [:]
                    )
                } else {
                    timeoutTimer?.cancel()
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
                    timeoutTimer?.start(onTimeout: {
                        pendingRequestCallbacks.enqueue { $0.cancel() }
                    })
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
        var pendingActions: [(RequestCallbacks<Data>) -> Void] = []
        self.lock.perform {
            self.callbacks = callbacks
            pendingActions = self.queue
            self.queue = []
        }
        for action in pendingActions {
            action(callbacks)
        }
    }

    func enqueue(_ action: @escaping (RequestCallbacks<Data>) -> Void) {
        var callbacksToCall: RequestCallbacks<Data>?
        self.lock.perform {
            if let callbacks = self.callbacks {
                callbacksToCall = callbacks
            } else {
                self.queue.append(action)
            }
        }
        if let callbacks = callbacksToCall {
            action(callbacks)
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
