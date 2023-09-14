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

/// HTTP request used for sending primitive data to the server.
public struct HTTPRequest: Sendable {
    /// Target URL for the request.
    public let url: URL
    /// Value to assign to the `content-type` header.
    public let contentType: String
    /// Additional outbound headers for the request.
    public let headers: Headers
    /// Body data to send with the request.
    public let message: Data?
    /// Outbound trailers for the request.
    public let trailers: Trailers?

    public init(
        url: URL, contentType: String, headers: Headers, message: Data?, trailers: Trailers?
    ) {
        self.url = url
        self.contentType = contentType
        self.headers = headers
        self.message = message
        self.trailers = trailers
    }
}
