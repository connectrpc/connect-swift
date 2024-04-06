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
import SwiftProtobuf

/// Primary interface consumed by generated RPCs to perform requests and streams.
/// The client itself is protocol-agnostic, but can be configured during initialization
/// (see `ProtocolClientConfig` and `ProtocolClientOption`).
public protocol ProtocolClientInterface: Sendable {
    // MARK: - Callbacks

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
    func unary<Input: ProtobufMessage, Output: ProtobufMessage>(
        path: String,
        idempotencyLevel: IdempotencyLevel,
        request: Input,
        headers: Headers,
        completion: @escaping @Sendable (ResponseMessage<Output>) -> Void
    ) -> Cancelable

    /// Start a new bidirectional stream.
    ///
    /// NOTE: The implementation is required to buffer inbound response data and pass complete
    /// chunks to its `Interceptor` list, in order to allow interceptors to consume full messages
    /// with each data chunk they are passed. For example, if 10 bytes are received but the prefix
    /// data indicates that the message is longer, the implementation must wait until the remaining
    /// bytes are received to pass the data down to its interceptors (and finally the caller).
    ///
    /// - parameter path: The RPC path, e.g., "connectrpc.eliza.v1.ElizaService/Converse".
    /// - parameter headers: The outbound request headers to include.
    /// - parameter onResult: Closure called whenever new results are received on the stream
    ///                       (response headers, messages, trailers, etc.).
    ///
    /// - returns: An interface for interacting with and sending data over the bidirectional stream.
    func bidirectionalStream<Input: ProtobufMessage, Output: ProtobufMessage>(
        path: String,
        headers: Headers,
        onResult: @escaping @Sendable (StreamResult<Output>) -> Void
    ) -> any BidirectionalStreamInterface<Input>

    /// Start a new client-only stream.
    ///
    /// NOTE: The implementation is required to buffer inbound response data and pass complete
    /// chunks to its `Interceptor` list, in order to allow interceptors to consume full messages
    /// with each data chunk they are passed. For example, if 10 bytes are received but the prefix
    /// data indicates that the message is longer, the implementation must wait until the remaining
    /// bytes are received to pass the data down to its interceptors (and finally the caller).
    ///
    /// - parameter path: The RPC path, e.g., "connectrpc.eliza.v1.ElizaService/Converse".
    /// - parameter headers: The outbound request headers to include.
    /// - parameter onResult: Closure called whenever new results are received on the stream
    ///                       (response headers, messages, trailers, etc.).
    ///
    /// - returns: An interface for interacting with and sending data over the client-only stream.
    func clientOnlyStream<Input: ProtobufMessage, Output: ProtobufMessage>(
        path: String,
        headers: Headers,
        onResult: @escaping @Sendable (StreamResult<Output>) -> Void
    ) -> any ClientOnlyStreamInterface<Input>

    /// Start a new server-only stream.
    ///
    /// NOTE: The implementation is required to buffer inbound response data and pass complete
    /// chunks to its `Interceptor` list, in order to allow interceptors to consume full messages
    /// with each data chunk they are passed. For example, if 10 bytes are received but the prefix
    /// data indicates that the message is longer, the implementation must wait until the remaining
    /// bytes are received to pass the data down to its interceptors (and finally the caller).
    ///
    /// - parameter path: The RPC path, e.g., "connectrpc.eliza.v1.ElizaService/Introduce".
    /// - parameter headers: The outbound request headers to include.
    /// - parameter onResult: Closure called whenever new results are received on the stream
    ///                       (response headers, messages, trailers, etc.).
    ///
    /// - returns: An interface for interacting with and sending data over the server-only stream.
    func serverOnlyStream<Input: ProtobufMessage, Output: ProtobufMessage>(
        path: String,
        headers: Headers,
        onResult: @escaping @Sendable (StreamResult<Output>) -> Void
    ) -> any ServerOnlyStreamInterface<Input>

    // MARK: - Async/await

    /// Perform a unary (non-streaming) request.
    ///
    /// - parameter path: The RPC path, e.g., "connectrpc.eliza.v1.ElizaService/Say".
    /// - parameter idempotencyLevel: The idempotency level of this RPC.
    /// - parameter request: The outbound request message.
    /// - parameter headers: The outbound request headers to include.
    ///
    /// - returns: The response which is returned asynchronously.
    @available(iOS 13, *)
    func unary<Input: ProtobufMessage, Output: ProtobufMessage>(
        path: String,
        idempotencyLevel: IdempotencyLevel,
        request: Input,
        headers: Headers
    ) async -> ResponseMessage<Output>

    /// Start a new bidirectional stream.
    ///
    /// NOTE: The implementation is required to buffer inbound response data and pass complete
    /// chunks to its `Interceptor` list, in order to allow interceptors to consume full messages
    /// with each data chunk they are passed. For example, if 10 bytes are received but the prefix
    /// data indicates that the message is longer, the implementation must wait until the remaining
    /// bytes are received to pass the data down to its interceptors (and finally the caller).
    ///
    /// - parameter path: The RPC path, e.g., "connectrpc.eliza.v1.ElizaService/Converse".
    /// - parameter headers: The outbound request headers to include.
    ///
    /// - returns: An interface for sending and receiving data over the stream using async/await.
    @available(iOS 13, *)
    func bidirectionalStream<Input: ProtobufMessage, Output: ProtobufMessage>(
        path: String,
        headers: Headers
    ) -> any BidirectionalAsyncStreamInterface<Input, Output>

    /// Start a new client-only stream.
    ///
    /// NOTE: The implementation is required to buffer inbound response data and pass complete
    /// chunks to its `Interceptor` list, in order to allow interceptors to consume full messages
    /// with each data chunk they are passed. For example, if 10 bytes are received but the prefix
    /// data indicates that the message is longer, the implementation must wait until the remaining
    /// bytes are received to pass the data down to its interceptors (and finally the caller).
    ///
    /// - parameter path: The RPC path, e.g., "connectrpc.eliza.v1.ElizaService/Converse".
    /// - parameter headers: The outbound request headers to include.
    ///
    /// - returns: An interface for sending and receiving data over the stream using async/await.
    @available(iOS 13, *)
    func clientOnlyStream<Input: ProtobufMessage, Output: ProtobufMessage>(
        path: String,
        headers: Headers
    ) -> any ClientOnlyAsyncStreamInterface<Input, Output>

    /// Start a new server-only stream.
    ///
    /// NOTE: The implementation is required to buffer inbound response data and pass complete
    /// chunks to its `Interceptor` list, in order to allow interceptors to consume full messages
    /// with each data chunk they are passed. For example, if 10 bytes are received but the prefix
    /// data indicates that the message is longer, the implementation must wait until the remaining
    /// bytes are received to pass the data down to its interceptors (and finally the caller).
    ///
    /// - parameter path: The RPC path, e.g., "connectrpc.eliza.v1.ElizaService/Introduce".
    /// - parameter headers: The outbound request headers to include.
    ///
    /// - returns: An interface for sending and receiving data over the stream using async/await.
    @available(iOS 13, *)
    func serverOnlyStream<Input: ProtobufMessage, Output: ProtobufMessage>(
        path: String,
        headers: Headers
    ) -> any ServerOnlyAsyncStreamInterface<Input, Output>
}
