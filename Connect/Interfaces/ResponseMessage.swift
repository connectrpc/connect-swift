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

import SwiftProtobuf

/// Typed unary response from an RPC.
public struct ResponseMessage<Output: SwiftProtobuf.Message> {
    /// The status code of the response.
    public let code: Code
    /// Response headers specified by the server.
    public let headers: Headers
    /// Typed response message provided by the server.
    public let message: Output?
    /// Trailers provided by the server.
    public let trailers: Trailers

    public init(
        code: Code = .ok, headers: Headers = [:], message: Output?, trailers: Trailers = [:]
    ) {
        self.code = code
        self.headers = headers
        self.message = message
        self.trailers = trailers
    }
}

extension Swift.Result where Failure == ConnectError {
    public var error: ConnectError? {
        switch self {
        case .success:
            return nil
        case .failure(let error):
            return error
        }
    }

    public var response: Success? {
        switch self {
        case .success(let message):
            return message
        case .failure:
            return nil
        }
    }
}
