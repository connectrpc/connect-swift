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
public protocol Interceptor {
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

open class AsyncInterceptor: Interceptor {
    open func handleRequest(_ request: HTTPRequest) async -> HTTPRequest {
        return request
    }

    open func handleUnaryResponse(_ response: HTTPResponse) async -> HTTPResponse {
        return response
    }

    open func handleUnaryResponseMetrics(_ metrics: HTTPMetrics) async -> HTTPMetrics {
        return metrics
    }

    open func handleStreamRequestData(_ data: Data) async -> Data {
        return data
    }

    open func handleStreamResult(_ result: StreamResult<Data>) async -> StreamResult<Data> {
        return result
    }

    public final func unaryFunction() -> UnaryFunction {
        return .init { request, proceed in
            Task {
                proceed(await self.handleRequest(request))
            }
        } responseFunction: { response, proceed in
            Task {
                proceed(await self.handleUnaryResponse(response))
            }
        } responseMetricsFunction: { metrics, proceed in
            Task {
                proceed(await self.handleUnaryResponseMetrics(metrics))
            }
        }
    }

    public final func streamFunction() -> StreamFunction {
        return .init { request, proceed in
            Task {
                proceed(await self.handleRequest(request))
            }
        } requestDataFunction: { data, proceed in
            Task {
                proceed(await self.handleStreamRequestData(data))
            }
        } streamResultFunction: { result, proceed in
            Task {
                proceed(await self.handleStreamResult(result))
            }
        }
    }
}

public struct UnaryFunction: @unchecked Sendable {
    public let requestFunction: RequestHandler
    public let responseFunction: ResponseHandler
    public let responseMetricsFunction: ResponseMetricsHandler

    public typealias RequestHandler = (
        _ request: HTTPRequest, _ proceed: @escaping (HTTPRequest) -> Void
    ) -> Void
    public typealias ResponseHandler = (
        _ response: HTTPResponse, _ proceed: @escaping (HTTPResponse) -> Void
    ) -> Void
    public typealias ResponseMetricsHandler = (
        _ metrics: HTTPMetrics, _ proceed: @escaping (HTTPMetrics) -> Void
    ) -> Void

    public init(
        requestFunction: @escaping RequestHandler,
        responseFunction: @escaping ResponseHandler,
        responseMetricsFunction: @escaping ResponseMetricsHandler = { $1($0) }
    ) {
        self.requestFunction = requestFunction
        self.responseFunction = responseFunction
        self.responseMetricsFunction = responseMetricsFunction
    }
}

public struct StreamFunction: @unchecked Sendable {
    public let requestFunction: RequestHandler
    public let requestDataFunction: RequestDataHandler
    public let streamResultFunction: StreamResultHandler

    public typealias RequestHandler = (
        _ request: HTTPRequest, _ proceed: @escaping (HTTPRequest) -> Void
    ) -> Void
    public typealias RequestDataHandler = (
        _ data: Data, _ proceed: @escaping (Data) -> Void
    ) -> Void
    public typealias StreamResultHandler = (
        _ result: StreamResult<Data>, _ proceed: @escaping (StreamResult<Data>) -> Void
    ) -> Void

    public init(
        requestFunction: @escaping RequestHandler,
        requestDataFunction: @escaping RequestDataHandler,
        streamResultFunction: @escaping StreamResultHandler
    ) {
        self.requestFunction = requestFunction
        self.requestDataFunction = requestDataFunction
        self.streamResultFunction = streamResultFunction
    }
}
