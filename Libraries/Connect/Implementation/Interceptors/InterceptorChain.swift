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

/// Represents a chain of interceptors that is used for a single request/stream,
/// and orchestrates invoking each of them in the proper order.
struct InterceptorChain {
    private let interceptors: [Interceptor]

    /// Initialize the interceptor chain.
    ///
    /// NOTE: Exactly 1 chain is expected to be instantiated for a single request/stream.
    ///
    /// - parameter interceptors: Closures that should be called to create interceptors.
    /// - parameter config: Config to use for setting up interceptors.
    init(
        interceptors: [(ProtocolClientConfig) -> Interceptor], config: ProtocolClientConfig
    ) {
        self.interceptors = interceptors.map { initialize in initialize(config) }
    }

    /// Create a set of closures configured with all interceptors for a unary API.
    ///
    /// NOTE: Interceptors are invoked in FIFO order for the request path, and in LIFO order for
    /// the response path. For example, with interceptors `[a, b, c]`:
    /// `caller -> a -> b -> c -> server`
    /// `caller <- c <- b <- a <- server`
    ///
    /// - parameter send: <#UnaryFunction#>
    ///
    /// - returns: A set of closures that each invoke the chain of interceptors in the above order.
    func unaryFunction(send: UnaryFunction) -> UnaryFunction {
        var next = send
        for interceptor in self.interceptors {
            next = UnaryFunction(requestFunction: <#T##(HTTPRequest) -> Void#>, responseFunction: <#T##(HTTPResponse) -> Void#>, responseMetricsFunction: <#T##(HTTPMetrics) -> Void#>)
        }
        let interceptors = self.interceptors.map { $0.unaryFunction() }
        return UnaryFunction(
            requestFunction: { request in
                return executeInterceptors(interceptors.map(\.requestFunction), initial: request)
            },
            responseFunction: { response in
                return executeInterceptors(
                    interceptors.reversed().map(\.responseFunction),
                    initial: response
                )
            },
            responseMetricsFunction: { metrics in
                return executeInterceptors(
                    interceptors.reversed().map(\.responseMetricsFunction),
                    initial: metrics
                )
            }
        )
    }

    /// Create a set of closures configured with all interceptors for a stream.
    ///
    /// NOTE: Interceptors are invoked in FIFO order for the request path, and in LIFO order for
    /// the response path. For example, with interceptors `[a, b, c]`:
    /// `caller -> a -> b -> c -> server`
    /// `caller <- c <- b <- a <- server`
    ///
    /// - returns: A set of closures that each invoke the chain of interceptors in the above order.
    func streamFunction() -> StreamFunction {
        let interceptors = self.interceptors.map { $0.streamFunction() }
        return StreamFunction(
            requestFunction: { request in
                return executeInterceptors(interceptors.map(\.requestFunction), initial: request)
            },
            requestDataFunction: { data in
                return executeInterceptors(interceptors.map(\.requestDataFunction), initial: data)
            },
            streamResultFunction: { result in
                return executeInterceptors(
                    interceptors.reversed().map(\.streamResultFunction),
                    initial: result
                )
            }
        )
    }
}
