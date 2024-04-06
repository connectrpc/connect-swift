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

/// Mock implementation of `ServerOnlyStreamInterface` which can be used for testing.
///
/// This type can be used by setting `on*` closures and observing their calls,
/// by validating its instance variables such as `inputs` at the end of invocation,
/// or by subclassing the type and overriding functions such as `send()`.
///
/// To return data over the stream, outputs can be specified using `init(outputs: ...)`.
@available(iOS 13, *)
open class MockServerOnlyStream<
    Input: ProtobufMessage,
    Output: ProtobufMessage
>: ServerOnlyStreamInterface, @unchecked Sendable {
    /// Closure that is called when `send()` is invoked.
    public var onSend: ((Input) -> Void)?
    /// The list of outputs to return to the client once one input has been sent.
    public var outputs: [StreamResult<Output>]

    /// All inputs that have been sent through the stream.
    @Published public private(set) var inputs = [Input]()

    /// Designated initializer.
    ///
    /// - parameter outputs: The list of outputs to return to the client once one input has been
    ///                      sent.
    public init(outputs: [StreamResult<Output>] = []) {
        self.outputs = outputs
    }

    open func send(_ input: Input) {
        self.inputs.append(input)
        self.onSend?(input)
    }

    open func cancel() {}
}
