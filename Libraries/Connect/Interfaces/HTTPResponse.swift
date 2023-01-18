// Copyright 2022-2023 Buf Technologies, Inc.
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

/// Unary HTTP response received from the server.
public struct HTTPResponse {
    /// The status code of the response.
    public let code: Code
    /// Response headers specified by the server.
    public let headers: Headers
    /// HTTP status received by the response. Note that `code` is generally preferred,
    /// except for HTTP-specific use cases such as tracing.
    /// Nil in cases where no response was received from the server.
    public let httpStatus: Int?
    /// Body data provided by the server.
    public let message: Data?
    /// Trailers provided by the server.
    public let trailers: Trailers
    /// The accompanying error, if the request failed.
    public let error: Swift.Error?

    public init(
        code: Code, headers: Headers, httpStatus: Int?,
        message: Data?, trailers: Trailers, error: Error?
    ) {
        self.code = code
        self.headers = headers
        self.httpStatus = httpStatus
        self.message = message
        self.trailers = trailers
        self.error = error
    }
}
