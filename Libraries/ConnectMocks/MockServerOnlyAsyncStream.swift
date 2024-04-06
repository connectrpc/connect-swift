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

import Combine
import Connect
import SwiftProtobuf

/// Mock implementation of `ServerOnlyAsyncStreamInterface` which can be used for testing.
///
/// This type can be used by setting `on*` closures and observing their calls,
/// by validating its instance variables such as `inputs` at the end of invocation,
/// or by subclassing the type and overriding functions such as `send()`.
///
/// To return data over the stream, outputs can be specified using `init(outputs: ...)` or by
/// subclassing and overriding `results()`.
@available(iOS 13, *)
open class MockServerOnlyAsyncStream<
    Input: ProtobufMessage,
    Output: ProtobufMessage
>: ServerOnlyAsyncStreamInterface, @unchecked Sendable {
    /// Used to store cancellables from the stream.
    private var cancellables = [AnyCancellable]()

    /// Closure that is called when `send()` is invoked.
    public var onSend: ((Input) -> Void)?
    /// The list of outputs to return to calls to the `results()` function
    /// once one input has been sent.
    public var outputs: [StreamResult<Output>]

    /// All inputs that have been sent through the stream.
    @Published public private(set) var inputs = [Input]()

    /// Designated initializer.
    ///
    /// - parameter outputs: The list of outputs to return to calls to the `results()` function once
    ///                      one input has been sent.
    public init(outputs: [StreamResult<Output>] = []) {
        self.outputs = outputs
    }

    open func send(_ input: Input) throws {
        self.inputs.append(input)
        self.onSend?(input)
    }

    open func results() -> AsyncStream<Connect.StreamResult<Output>> {
        // Wait until a request is sent over the stream to return the results.
        return AsyncStream { continuation in
            self.$inputs
                .first { !$0.isEmpty }
                .sink { _ in
                    for output in self.outputs {
                        continuation.yield(output)
                    }
                    continuation.finish()
                }
                .store(in: &self.cancellables)
        }
    }

    open func cancel() {}
}
