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

/// Request used for sending data to the server.
public struct HTTPRequest<Input: Sendable>: Sendable {
    /// Target URL for the request.
    public let url: URL
    /// Additional outbound headers for the request.
    public let headers: Headers
    /// Data to send with the request.
    public let message: Input
    /// HTTP method to use for the request.
    public let method: HTTPMethod
    /// Outbound trailers for the request.
    public let trailers: Trailers?
    /// Idempotency level of the request.
    public let idempotencyLevel: IdempotencyLevel

    public init(
        url: URL, headers: Headers, message: Input, method: HTTPMethod,
        trailers: Trailers?, idempotencyLevel: IdempotencyLevel
    ) {
        self.url = url
        self.headers = headers
        self.message = message
        self.method = method
        self.trailers = trailers
        self.idempotencyLevel = idempotencyLevel
    }
}
