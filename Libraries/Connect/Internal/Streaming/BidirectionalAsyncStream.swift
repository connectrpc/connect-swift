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

import SwiftProtobuf

/// Concrete implementation of `BidirectionalAsyncStreamInterface`.
/// Provides the necessary wiring to bridge from closures/callbacks to Swift's `AsyncStream`
/// to work with async/await.
@available(iOS 13, *)
final class BidirectionalAsyncStream<
    Input: ProtobufMessage, Output: ProtobufMessage
>: @unchecked Sendable {
    /// The underlying async stream that will be exposed to the consumer.
    /// Force unwrapped because it captures `self` on `init`.
    private var asyncStream: AsyncStream<StreamResult<Output>>!
    /// Stored closure to provide access to the `AsyncStream.Continuation` so that result data
    /// can be passed through to the `AsyncStream` when received.
    /// Force unwrapped because it must be set within the context of the `AsyncStream.Continuation`.
    private var receiveResult: ((StreamResult<Output>) -> Void)!
    /// Callbacks used to send outbound data and close the stream.
    /// Optional because these callbacks are not available until the stream is initialized.
    private var requestCallbacks: RequestCallbacks<Input>?

    private struct NotConfiguredForSendingError: Swift.Error {}

    /// Initialize a new stream.
    ///
    /// Note: `configureForSending()` must be called before using the stream.
    init() {
        self.asyncStream = AsyncStream<StreamResult<Output>> { continuation in
            self.receiveResult = { result in
                if Task.isCancelled {
                    return
                }
                switch result {
                case .headers, .message:
                    continuation.yield(result)
                case .complete:
                    continuation.yield(result)
                    continuation.finish()
                }
            }
            continuation.onTermination = { @Sendable _ in
                self.requestCallbacks?.sendClose()
            }
        }
    }

    /// Enable sending data over this stream by providing a set of request callbacks to route data
    /// to the network client. Must be called before calling `send()`.
    ///
    /// - parameter requestCallbacks: Callbacks to use for sending request data and closing the
    ///                               stream.
    ///
    /// - returns: This instance of the stream (useful for chaining).
    @discardableResult
    func configureForSending(with requestCallbacks: RequestCallbacks<Input>) -> Self {
        self.requestCallbacks = requestCallbacks
        return self
    }

    /// Send a result to the consumer over the `results()` `AsyncStream`.
    /// Should be called by the protocol client when a result is received.
    ///
    /// - parameter result: The new result that was received.
    func receive(_ result: StreamResult<Output>) {
        self.receiveResult(result)
    }
}

@available(iOS 13, *)
extension BidirectionalAsyncStream: BidirectionalAsyncStreamInterface {
    @discardableResult
    func send(_ input: Input) throws -> Self {
        guard let sendData = self.requestCallbacks?.sendData else {
            throw NotConfiguredForSendingError()
        }

        sendData(input)
        return self
    }

    func results() -> AsyncStream<StreamResult<Output>> {
        return self.asyncStream
    }

    func close() {
        self.requestCallbacks?.sendClose()
    }

    func cancel() {
        self.requestCallbacks?.cancel()
    }
}

// Conforms to the client-only interface since it matches exactly and the implementation is internal
@available(iOS 13, *)
extension BidirectionalAsyncStream: ClientOnlyAsyncStreamInterface {}
