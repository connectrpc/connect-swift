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

/// Interceptors can be registered with clients as a way to observe and/or alter outbound requests
/// and inbound responses.
///
/// Interceptors are expected to be instantiated once per request/stream.
public protocol Interceptor: Sendable {
    /// Invoked when a unary call is started. Provides a set of closures that will be called
    /// as the request progresses, allowing the interceptor to alter request/response data.
    ///
    /// - returns: A new set of closures which can be used to read/alter request/response data.
    func unaryFunction() -> UnaryFunction

    /// Invoked when a streaming call is started. Provides a set of closures that will be called
    /// as the stream progresses, allowing the interceptor to alter request/response data.
    ///
    /// NOTE: Closures may be called multiple times as the stream progresses (for example, as data
    /// is sent/received over the stream). Furthermore, a guarantee is provided that each data chunk
    /// will contain 1 full message (for Connect and gRPC, this includes the prefix and message
    /// length bytes, followed by the actual message data).
    ///
    /// - returns: A new set of closures which can be used to read/alter request/response data.
    func streamFunction() -> StreamFunction
}

public typealias InterceptorInitializer = @Sendable (ProtocolClientConfig) -> Interceptor

public struct UnaryFunction: Sendable {
    public let requestFunction: @Sendable (HTTPRequest) -> HTTPRequest
    public let responseFunction: @Sendable (HTTPResponse) -> HTTPResponse
    public let responseMetricsFunction: @Sendable (HTTPMetrics) -> HTTPMetrics

    public init(
        requestFunction: @escaping @Sendable (HTTPRequest) -> HTTPRequest,
        responseFunction: @escaping @Sendable (HTTPResponse) -> HTTPResponse,
        responseMetricsFunction: @escaping @Sendable (HTTPMetrics) -> HTTPMetrics = { $0 }
    ) {
        self.requestFunction = requestFunction
        self.responseFunction = responseFunction
        self.responseMetricsFunction = responseMetricsFunction
    }
}

public struct StreamFunction: Sendable {
    public let requestFunction: @Sendable (HTTPRequest) -> HTTPRequest
    public let requestDataFunction: @Sendable (Data) -> Data
    public let streamResultFunction: @Sendable (StreamResult<Data>) -> StreamResult<Data>

    public init(
        requestFunction: @escaping @Sendable (HTTPRequest) -> HTTPRequest,
        requestDataFunction: @escaping @Sendable (Data) -> Data,
        streamResultFunction: @escaping @Sendable (StreamResult<Data>) -> StreamResult<Data>
    ) {
        self.requestFunction = requestFunction
        self.requestDataFunction = requestDataFunction
        self.streamResultFunction = streamResultFunction
    }
}
