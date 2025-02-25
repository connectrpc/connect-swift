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

/// Represents a bidirectional stream that can send request messages and initiate closes.
public protocol BidirectionalStreamInterface<Input> {
    /// The input (request) message type.
    associatedtype Input: ProtobufMessage

    /// Send a request to the server over the stream.
    ///
    /// - parameter input: The request message to send.
    ///
    /// - returns: An instance of this stream, for syntactic sugar.
    @discardableResult
    func send(_ input: Input) -> Self

    /// Close the stream. No calls to `send()` are valid after calling `close()`.
    func close()

    /// Cancel the stream and return a canceled code.
    /// No calls to `send()` are valid after calling `cancel()`.
    func cancel()
}
