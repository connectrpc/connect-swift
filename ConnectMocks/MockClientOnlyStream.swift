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

/// Mock implementation of `ClientOnlyStreamInterface` which can be used for testing.
///
/// This type can be used by setting `on*` closures and observing their calls,
/// by validating its instance variables like `inputs` at the end of invocation,
/// or by subclassing the type and overriding functions such as `send()`.
open class MockClientOnlyStream<
    Input: SwiftProtobuf.Message,
    Output: SwiftProtobuf.Message
>: MockBidirectionalStream<Input, Output>, ClientOnlyStreamInterface {}
