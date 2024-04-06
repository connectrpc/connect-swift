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

/// Unary HTTP response received from the server.
public struct HTTPResponse: Sendable {
    /// The status code of the response.
    /// See https://connectrpc.com/docs/protocol/#error-codes for more info.
    public let code: Code
    /// Response headers specified by the server.
    public let headers: Headers
    /// Body data provided by the server.
    public let message: Data?
    /// Trailers provided by the server.
    public let trailers: Trailers
    /// The accompanying error, if the request failed.
    public let error: Swift.Error?
    /// Tracing information that can be used for logging or debugging network-level details.
    /// This information is expected to change when switching protocols (i.e., from Connect to
    /// gRPC-Web), as each protocol has different HTTP semantics.
    /// Nil in cases where no response was received from the server.
    public let tracingInfo: TracingInfo?

    public struct TracingInfo: Equatable, Sendable {
        /// HTTP status received from the server.
        public let httpStatus: Int

        public init(httpStatus: Int) {
            self.httpStatus = httpStatus
        }
    }

    public init(
        code: Code, headers: Headers, message: Data?,
        trailers: Trailers, error: Swift.Error?, tracingInfo: TracingInfo?
    ) {
        self.code = code
        self.headers = headers
        self.message = message
        self.trailers = trailers
        self.error = error
        self.tracingInfo = tracingInfo
    }
}
