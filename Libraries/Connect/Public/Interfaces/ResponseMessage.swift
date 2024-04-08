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

/// Typed unary response from an RPC.
public struct ResponseMessage<Output: ProtobufMessage>: Sendable {
    /// The status code of the response.
    public let code: Code
    /// Response headers specified by the server.
    public let headers: Headers
    /// The result of the RPC (either a message or an error).
    public let result: Result<Output, ConnectError>
    /// Trailers provided by the server.
    public let trailers: Trailers

    /// Convenience accessor for the `result`'s wrapped error.
    public var error: ConnectError? {
        switch self.result {
        case .success:
            return nil
        case .failure(let error):
            return error
        }
    }

    /// Convenience accessor for the `result`'s wrapped message.
    public var message: Output? {
        switch self.result {
        case .success(let message):
            return message
        case .failure:
            return nil
        }
    }

    public init(
        code: Code = .ok, headers: Headers = [:],
        result: Result<Output, ConnectError>, trailers: Trailers = [:]
    ) {
        self.code = code
        self.headers = headers
        self.result = result
        self.trailers = trailers
    }
}
