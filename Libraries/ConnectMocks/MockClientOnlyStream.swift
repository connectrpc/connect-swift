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

/// Mock implementation of `ClientOnlyStreamInterface` which can be used for testing.
///
/// This type can be used by setting `on*` closures and observing their calls,
/// by validating its instance variables such as `inputs` at the end of invocation,
/// or by subclassing the type and overriding functions such as `send()`.
///
/// To return data over the stream, outputs can be specified using `init(outputs: ...)`.
///
/// Note: This class does not handle thread-safe locking, but provides `@unchecked Sendable`
/// conformance to simplify testing and mocking. It is intended for single-test use: configure
/// it, exercise it, then assert on it. Do not share an instance across concurrent tests or
/// mutate its properties from multiple threads.
@available(iOS 13, *)
open class MockClientOnlyStream<
    Input: ProtobufMessage,
    Output: ProtobufMessage
>: MockBidirectionalStream<Input, Output>, ClientOnlyStreamInterface, @unchecked Sendable {
    open func closeAndReceive() {
        self.close()
    }
}
