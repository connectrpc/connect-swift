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

/// Represents a server-only stream (a stream where the server streams data to the client after
/// receiving an initial request) that can send request messages.
public protocol ServerOnlyStreamInterface<Input> {
    /// The input (request) message type.
    associatedtype Input: ProtobufMessage

    /// Send a request to the server over the stream.
    ///
    /// Should be called exactly one time when starting the stream.
    ///
    /// - parameter input: The request message to send.
    func send(_ input: Input)

    /// Cancel the stream and return a canceled code.
    /// No calls to `send()` are valid after calling `cancel()`.
    func cancel()
}
