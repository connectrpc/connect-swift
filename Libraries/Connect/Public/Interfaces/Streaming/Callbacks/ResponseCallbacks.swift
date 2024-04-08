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

import Foundation

/// Set of closures that are used for wiring inbound response data through from HTTP clients.
public final class ResponseCallbacks: Sendable {
    /// Closure to call when response headers are available.
    public let receiveResponseHeaders: @Sendable (Headers) -> Void
    /// Closure to call when response data is available.
    public let receiveResponseData: @Sendable (Data) -> Void
    /// Closure to call when response metrics are available.
    public let receiveResponseMetrics: @Sendable (HTTPMetrics) -> Void
    /// Closure to call when the stream is closed.
    /// Includes the status code, trailers, and potentially an error.
    public let receiveClose: @Sendable (Code, Trailers, Swift.Error?) -> Void

    public init(
        receiveResponseHeaders: @escaping @Sendable (Headers) -> Void,
        receiveResponseData: @escaping @Sendable (Data) -> Void,
        receiveResponseMetrics: @escaping @Sendable (HTTPMetrics) -> Void,
        receiveClose: @escaping @Sendable (Code, Trailers, Swift.Error?) -> Void
    ) {
        self.receiveResponseHeaders = receiveResponseHeaders
        self.receiveResponseData = receiveResponseData
        self.receiveResponseMetrics = receiveResponseMetrics
        self.receiveClose = receiveClose
    }
}
