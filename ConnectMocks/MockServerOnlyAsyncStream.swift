// Copyright 2022 Buf Technologies, Inc.
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

/// Mock implementation of `ServerOnlyAsyncStreamInterface` which can be used for testing.
///
/// This type can be used by setting `on*` closures and observing their calls,
/// by validating its instance variables like `inputs` at the end of invocation,
/// or by subclassing the type and overriding functions such as `send()`.
///
/// To return data over the stream, outputs can be specified using `init(outputs: ...)` or by
/// subclassing and overriding `results()`.
open class MockServerOnlyAsyncStream<
    Input: SwiftProtobuf.Message,
    Output: SwiftProtobuf.Message
>: ServerOnlyAsyncStreamInterface {
    private let outputs: [StreamResult<Output>]

    /// Closure that is called when `close()` is invoked.
    public var onClose: (() -> Void)?
    /// Closure that is called when `send()` is invoked.
    public var onSend: ((Input) -> Void)?

    /// All inputs that have been sent through the stream.
    public private(set) var inputs = [Input]()
    /// True if `close()` has been called.
    public private(set) var isClosed = false

    /// Designated initializer.
    ///
    /// - parameter outputs: The list of outputs to return to calls to the `results()` function.
    public init(outputs: [StreamResult<Output>] = []) {
        self.outputs = outputs
    }

    open func send(_ input: Input) throws {
        self.inputs.append(input)
        self.onSend?(input)
    }

    open func results() -> AsyncStream<Connect.StreamResult<Output>> {
        var outputs = Array(self.outputs)
        return AsyncStream(unfolding: {
            return outputs.isEmpty ? nil : outputs.removeFirst()
        })
    }

    open func close() {
        self.isClosed = true
        self.onClose?()
    }
}
