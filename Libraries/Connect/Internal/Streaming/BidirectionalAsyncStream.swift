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

/// Concrete **internal** implementation of `BidirectionalAsyncStreamInterface`.
/// Provides the necessary wiring to bridge from closures/callbacks to Swift's `AsyncStream`
/// to work with async/await.
///
/// If the library removes callback support in favor of only supporting async/await in the future,
/// this class can be simplified.
final class BidirectionalAsyncStream<
    Input: ProtobufMessage, Output: ProtobufMessage
>: Sendable {
    /// The underlying async stream that will be exposed to the consumer.
    private let asyncStream: AsyncStream<StreamResult<Output>>
    /// Continuation used to pass result data through to the `AsyncStream` when received.
    private let continuation: AsyncStream<StreamResult<Output>>.Continuation
    /// Callbacks used to send outbound data and close the stream.
    /// Empty until the stream is initialized via `configureForSending()`.
    private let requestCallbacks = Locked<RequestCallbacks<Input>?>(nil)

    private struct NotConfiguredForSendingError: Swift.Error {}

    /// Initialize a new stream.
    ///
    /// Note: `configureForSending()` must be called before using the stream.
    init() {
        let (asyncStream, continuation) = AsyncStream.makeStream(of: StreamResult<Output>.self)
        self.asyncStream = asyncStream
        self.continuation = continuation
        // Capture the lock box rather than `self` so the continuation's stored termination
        // handler does not retain this instance.
        continuation.onTermination = { [requestCallbacks] _ in
            requestCallbacks.value?.sendClose()
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
        self.requestCallbacks.value = requestCallbacks
        return self
    }

    /// Send a result to the consumer over the `results()` `AsyncStream`.
    /// Should be called by the protocol client when a result is received from the network.
    ///
    /// - parameter result: The new result that was received.
    func handleResultFromServer(_ result: StreamResult<Output>) {
        if Task.isCancelled {
            return
        }
        switch result {
        case .headers, .message:
            self.continuation.yield(result)
        case .complete:
            self.continuation.yield(result)
            self.continuation.finish()
        }
    }
}

extension BidirectionalAsyncStream: BidirectionalAsyncStreamInterface {
    @discardableResult
    func send(_ input: Input) throws -> Self {
        guard let sendData = self.requestCallbacks.value?.sendData else {
            throw NotConfiguredForSendingError()
        }

        sendData(input)
        return self
    }

    func results() -> AsyncStream<StreamResult<Output>> {
        return self.asyncStream
    }

    func close() {
        self.requestCallbacks.value?.sendClose()
    }

    func cancel() {
        self.requestCallbacks.value?.cancel()
    }
}
