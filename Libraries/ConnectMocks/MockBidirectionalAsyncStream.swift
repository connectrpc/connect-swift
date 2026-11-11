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

import Connect
import SwiftProtobuf

/// Mock implementation of `BidirectionalAsyncStreamInterface` which can be used for testing.
///
/// This type can be used by setting `on*` closures and observing their calls,
/// by validating its instance variables such as `inputs` at the end of invocation,
/// or by subclassing the type and overriding functions such as `send()`.
///
/// To return data over the stream, outputs can be specified using `init(outputs: ...)` or by
/// subclassing and overriding `results()`.
open class MockBidirectionalAsyncStream<
    Input: ProtobufMessage,
    Output: ProtobufMessage
>: BidirectionalAsyncStreamInterface, @unchecked Sendable {
    /// The stream returned by `results()`, created on that function's first call and then reused.
    private var resultsStream: AsyncStream<StreamResult<Output>>?
    /// Set to `nil` once `outputs` have been emitted so that they are emitted only one time.
    private var resultsContinuation: AsyncStream<StreamResult<Output>>.Continuation?

    /// Closure that is called when `close()` is invoked.
    public var onClose: (() -> Void)?
    /// Closure that is called when `send()` is invoked.
    public var onSend: ((Input) -> Void)?
    /// The list of outputs to return to calls to the `results()` function
    /// once one input has been sent.
    public var outputs: [StreamResult<Output>]

    /// All inputs that have been sent through the stream.
    public private(set) var inputs = [Input]()
    /// True if `close()` has been called.
    public private(set) var isClosed = false

    /// Designated initializer.
    ///
    /// - parameter outputs: The list of outputs to return to calls to the `results()` function once
    ///                      one input has been sent.
    public init(outputs: [StreamResult<Output>] = []) {
        self.outputs = outputs
    }

    @discardableResult
    open func send(_ input: Input) throws -> Self {
        self.inputs.append(input)
        self.onSend?(input)
        self.emitOutputsIfReady()
        return self
    }

    /// Returns the same stream on every call, matching the production implementation.
    /// `outputs` are emitted and the stream is finished once an input has been sent,
    /// regardless of whether `send()` or this function is called first.
    open func results() -> AsyncStream<Connect.StreamResult<Output>> {
        if let resultsStream = self.resultsStream {
            return resultsStream
        }

        let (stream, continuation) = AsyncStream.makeStream(of: StreamResult<Output>.self)
        self.resultsStream = stream
        self.resultsContinuation = continuation
        self.emitOutputsIfReady()
        return stream
    }

    open func close() {
        self.isClosed = true
        self.onClose?()
    }

    open func cancel() {}

    private func emitOutputsIfReady() {
        guard !self.inputs.isEmpty, let continuation = self.resultsContinuation else {
            return
        }

        self.resultsContinuation = nil
        for output in self.outputs {
            continuation.yield(output)
        }
        continuation.finish()
    }
}
