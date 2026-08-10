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
        let timeoutTimer = TimeoutTimer(config: self.config)
        let interceptorChain = self.config.createStreamInterceptorChain()

        let (inbound, inboundContinuation) = AsyncStream.makeStream(of: InboundEvent.self)
        // Unbounded on purpose: `ProtocolClientInterface`'s stream methods are synchronous and
        // hand back a handle immediately, so sends made before the transport exists must be
        // buffered.
        let (outbound, outboundContinuation) = AsyncStream.makeStream(of: OutboundEvent<Input>.self)

        let responseCallbacks = ResponseCallbacks(
            receiveResponseHeaders: { inboundContinuation.yield(.result(.headers($0))) },
            receiveResponseData: { inboundContinuation.yield(.chunk($0)) },
            receiveResponseMetrics: { metrics in
                Task { _ = await interceptorChain.executeMetrics(metrics) }
            },
            receiveClose: { code, trailers, error in
                inboundContinuation.yield(
                    .result(.complete(code: code, error: error, trailers: trailers))
                )
                // The transport's close is its last event. Buffered elements are still delivered
                // after `finish()`, so this releases the inbound pump without dropping anything.
                inboundContinuation.finish()
            }
        )

        Task {
            var buffer = Data()
            // Not a lock: this task is the only reader and writer. Still required -
            // `ConnectInterceptor` converts an end-stream `.message` frame into `.complete` inside
            // the chain, and the transport then also fires `receiveClose`, so the duplicate
            // originates downstream of the events `finish()` can absorb.
            var hasCompleted = false

            for await event in inbound {
                var rawResults = [StreamResult<Data>]()
                switch event {
                case .result(let raw):
                    guard case .complete(let code, let error, let trailers) = raw else {
                        rawResults = [raw]
                        break
                    }
                    if hasCompleted {
                        continue
                    }

                    // The transport only ever reports `.canceled`, so the timer is how a deadline
                    // is told apart from a caller-initiated cancelation.
                    if code == .canceled && timeoutTimer?.timedOut == true {
                        let deadlineError = ConnectError(
                            code: .deadlineExceeded,
                            message: "request exceeded allowed timeout",
                            exception: nil, details: [], metadata: [:]
                        )
                        rawResults = [
                            .complete(
                                code: .deadlineExceeded, error: deadlineError, trailers: trailers
                            ),
                        ]
                    } else {
                        timeoutTimer?.cancel()
                        rawResults = [.complete(code: code, error: error, trailers: trailers)]
                    }

                case .chunk(let chunk):
                    // Handle cases where multiple messages are received in a single chunk.
                    buffer += chunk
                    while true {
                        let messageLength = Envelope.messageLength(forPackedData: buffer)
                        if messageLength < 0 {
                            break
                        }

                        let prefixedMessageLength = Envelope.prefixLength + messageLength
                        guard buffer.count >= prefixedMessageLength else {
                            break
                        }

                        rawResults.append(.message(buffer.prefix(prefixedMessageLength)))
                        // `Envelope.messageLength(forPackedData:)` reads `data[1...4]` with
                        // absolute indices, so the remainder must be re-based into fresh storage.
                        // Keeping the slice silently reads the wrong four bytes on the next pass.
                        buffer = Data(buffer.suffix(from: prefixedMessageLength))
                    }
                }

                for rawResult in rawResults {
                    let intercepted = await interceptorChain.executeRawResult(rawResult)
                    // TODO: Surface the deserialization failure instead of dropping the result.
                    guard let typed = intercepted.toTyped(Output.self, using: codec) else {
                        continue
                    }

                    let result = await interceptorChain.executeResult(typed)
                    onResult(result)
                    if case .complete = result {
                        hasCompleted = true
                        // Ordered after `onResult`: delivering `.complete` finishes the consumer's
                        // `results()` stream, whose termination handler calls `sendClose()`. That
                        // close has to reach the outbound buffer before it is finished.
                        outboundContinuation.finish()
                    }
                }
            }
        }

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

        Task {
            let interceptedRequest: HTTPRequest<Void>
            do {
                interceptedRequest = try await interceptorChain.executeStart(request)
            } catch let error as ConnectError {
                // Matches the closure-based implementation this replaced: a failure on the
                // request path is delivered directly, without invoking the result interceptors.
                inboundContinuation.finish()
                onResult(.complete(code: error.code, error: error, trailers: error.metadata))
                return
            } catch let error {
                inboundContinuation.finish()
                onResult(.complete(code: .unknown, error: error, trailers: nil))
                return
            }

            let transport = self.httpClient.stream(
                request: HTTPRequest(
                    url: interceptedRequest.url,
                    headers: interceptedRequest.headers,
                    message: nil, // Message is void on stream creation.
                    method: interceptedRequest.method,
                    trailers: interceptedRequest.trailers,
                    idempotencyLevel: interceptedRequest.idempotencyLevel
                ),
                responseCallbacks: responseCallbacks
            )
            timeoutTimer?.start(onTimeout: { transport.cancel() })

            for await event in outbound {
                switch event {
                case .data(let message):
                    let intercepted = await interceptorChain.executeInput(message)
                    let serialized: Data
                    do {
                        serialized = try codec.serialize(message: intercepted)
                    } catch let error {
                        // TODO: Surface the serialization failure instead of dropping the message.
                        os_log(
                            .error,
                            "Failed to send request message which could not be serialized: %@",
                            error.localizedDescription
                        )
                        continue
                    }
                    transport.sendData(await interceptorChain.executeRawInput(serialized))

                case .close:
                    // Deliberately not terminal: `cancel()` after `close()` must still reach the
                    // transport.
                    transport.sendClose()

                case .cancel:
                    transport.cancel()
                    return
                }
            }
        }

        return RequestCallbacks<Input>(
            cancel: { outboundContinuation.yield(.cancel) },
            sendData: { outboundContinuation.yield(.data($0)) },
            sendClose: { outboundContinuation.yield(.close) }
        )
    }
}

private enum OutboundEvent<Input: ProtobufMessage>: Sendable {
    case data(Input)
    case close
    case cancel
}

/// Mirrors the `ResponseCallbacks` closures that carry stream results. `.chunk` is raw transport
/// bytes, not a framed message - re-framing happens in the inbound pump.
private enum InboundEvent: Sendable {
    case chunk(Data)
    case result(StreamResult<Data>) // `.headers` or `.complete`, straight from the transport.
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
