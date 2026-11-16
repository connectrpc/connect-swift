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

import SwiftProtobuf

// The callback API. Everything in this file is an adapter over the async API declared by
// `ProtocolClientInterface`: nothing else in the library knows that callbacks exist.

extension ProtocolClientInterface {
    /// Perform a unary (non-streaming) request.
    ///
    /// - parameter path: The RPC path, e.g., "connectrpc.eliza.v1.ElizaService/Say".
    /// - parameter idempotencyLevel: The idempotency level of this RPC.
    /// - parameter request: The outbound request message.
    /// - parameter headers: The outbound request headers to include.
    /// - parameter completion: Closure called when a response or error is received.
    ///
    /// - returns: A `Cancelable` which provides the ability to cancel the outbound request.
    @discardableResult
    public func unary<Input: ProtobufMessage, Output: ProtobufMessage>(
        path: String,
        idempotencyLevel: IdempotencyLevel,
        request: Input,
        headers: Headers,
        completion: @escaping @Sendable (ResponseMessage<Output>) -> Void
    ) -> Cancelable {
        let task = Task {
            completion(
                await self.unary(
                    path: path, idempotencyLevel: idempotencyLevel, request: request,
                    headers: headers
                )
            )
        }
        return Cancelable { task.cancel() }
    }

    /// Start a new bidirectional stream.
    ///
    /// - parameter path: The RPC path, e.g., "connectrpc.eliza.v1.ElizaService/Converse".
    /// - parameter headers: The outbound request headers to include.
    /// - parameter onResult: Closure called whenever new results are received on the stream
    ///                       (response headers, messages, trailers, etc.).
    ///
    /// - returns: An interface for interacting with and sending data over the bidirectional stream.
    public func bidirectionalStream<Input: ProtobufMessage, Output: ProtobufMessage>(
        path: String,
        headers: Headers,
        onResult: @escaping @Sendable (StreamResult<Output>) -> Void
    ) -> any BidirectionalStreamInterface<Input> {
        let stream: any BidirectionalAsyncStreamInterface<Input, Output> =
            self.bidirectionalStream(path: path, headers: headers)
        // The task holds `stream` until the final result, so a caller who drops the returned
        // handle keeps receiving results.
        Task {
            for await result in stream.results() {
                onResult(result)
            }
        }
        return CallbackBidirectionalStream(stream: stream)
    }

    /// Start a new client-only stream.
    ///
    /// - parameter path: The RPC path, e.g., "connectrpc.eliza.v1.ElizaService/Converse".
    /// - parameter headers: The outbound request headers to include.
    /// - parameter onResult: Closure called whenever new results are received on the stream
    ///                       (response headers, messages, trailers, etc.).
    ///
    /// - returns: An interface for interacting with and sending data over the client-only stream.
    public func clientOnlyStream<Input: ProtobufMessage, Output: ProtobufMessage>(
        path: String,
        headers: Headers,
        onResult: @escaping @Sendable (StreamResult<Output>) -> Void
    ) -> any ClientOnlyStreamInterface<Input> {
        let stream: any ClientOnlyAsyncStreamInterface<Input, Output> =
            self.clientOnlyStream(path: path, headers: headers)
        Task {
            for await result in stream.results() {
                onResult(result)
            }
        }
        return CallbackClientOnlyStream(stream: stream)
    }

    /// Start a new server-only stream.
    ///
    /// - parameter path: The RPC path, e.g., "connectrpc.eliza.v1.ElizaService/Introduce".
    /// - parameter headers: The outbound request headers to include.
    /// - parameter onResult: Closure called whenever new results are received on the stream
    ///                       (response headers, messages, trailers, etc.).
    ///
    /// - returns: An interface for interacting with and sending data over the server-only stream.
    public func serverOnlyStream<Input: ProtobufMessage, Output: ProtobufMessage>(
        path: String,
        headers: Headers,
        onResult: @escaping @Sendable (StreamResult<Output>) -> Void
    ) -> any ServerOnlyStreamInterface<Input> {
        let stream: any ServerOnlyAsyncStreamInterface<Input, Output> =
            self.serverOnlyStream(path: path, headers: headers)
        Task {
            for await result in stream.results() {
                onResult(result)
            }
        }
        return CallbackServerOnlyStream(stream: stream)
    }
}

private final class CallbackBidirectionalStream<
    Input: ProtobufMessage, Output: ProtobufMessage
>: BidirectionalStreamInterface, Sendable {
    private let stream: any BidirectionalAsyncStreamInterface<Input, Output>

    init(stream: any BidirectionalAsyncStreamInterface<Input, Output>) {
        self.stream = stream
    }

    @discardableResult
    func send(_ input: Input) -> Self {
        // This protocol's `send` cannot throw, so an error from the async stream has nowhere to go.
        _ = try? self.stream.send(input)
        return self
    }

    func close() {
        self.stream.close()
    }

    func cancel() {
        self.stream.cancel()
    }
}

private final class CallbackClientOnlyStream<
    Input: ProtobufMessage, Output: ProtobufMessage
>: ClientOnlyStreamInterface, Sendable {
    private let stream: any ClientOnlyAsyncStreamInterface<Input, Output>

    init(stream: any ClientOnlyAsyncStreamInterface<Input, Output>) {
        self.stream = stream
    }

    @discardableResult
    func send(_ input: Input) throws -> Self {
        try self.stream.send(input)
        return self
    }

    func closeAndReceive() {
        self.stream.closeAndReceive()
    }

    func cancel() {
        self.stream.cancel()
    }
}

private final class CallbackServerOnlyStream<
    Input: ProtobufMessage, Output: ProtobufMessage
>: ServerOnlyStreamInterface, Sendable {
    private let stream: any ServerOnlyAsyncStreamInterface<Input, Output>

    init(stream: any ServerOnlyAsyncStreamInterface<Input, Output>) {
        self.stream = stream
    }

    func send(_ input: Input) {
        // This protocol's `send` cannot throw, so an error from the async stream has nowhere to go.
        try? self.stream.send(input)
    }

    func cancel() {
        self.stream.cancel()
    }
}
