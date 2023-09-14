// Copyright 2022-2023 The Connect Authors
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

import Foundation

/// Set of closures that are used for wiring outbound request data through to HTTP clients.
public final class RequestCallbacks: Sendable {
    /// Closure to send data through to the server.
    public let sendData: @Sendable (Data) -> Void
    /// Closure to initiate a close for a stream.
    public let sendClose: @Sendable () -> Void

    public init(
        sendData: @escaping @Sendable (Data) -> Void, sendClose: @escaping @Sendable () -> Void
    ) {
        self.sendData = sendData
        self.sendClose = sendClose
    }
}
