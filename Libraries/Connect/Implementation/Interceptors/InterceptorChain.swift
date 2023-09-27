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

/// Represents a chain of interceptors that is used for a single request/stream,
/// and orchestrates invoking each of them in the proper order.
struct InterceptorChain: @unchecked Sendable {
    private let interceptors: [Interceptor]

    /// Initialize the interceptor chain.
    ///
    /// NOTE: Exactly 1 chain is expected to be instantiated for a single request/stream.
    ///
    /// - parameter interceptors: Closures that should be called to create interceptors.
    /// - parameter config: Config to use for setting up interceptors.
    init(interceptors: [InterceptorInitializer], config: ProtocolClientConfig) {
        self.interceptors = interceptors.map { initialize in initialize(config) }
    }

    /// Create a set of closures configured with all interceptors for a unary API.
    ///
    /// NOTE: Interceptors are invoked in FIFO order for the request path, and in LIFO order for
    /// the response path. For example, with interceptors `[a, b, c]`:
    /// `caller -> a -> b -> c -> server`
    /// `caller <- c <- b <- a <- server`
    ///
    /// - parameter sendFunction: <#UnaryFunction#>
    ///
    /// - returns: <#UnaryFunction#>
    func chainUnary(_ sendFunction: UnaryFunction) -> UnaryFunction {
        let interceptors = self.interceptors.map { $0.unaryFunction() }
        return UnaryFunction { request, proceed in
            executeInterceptors(
                interceptors.map(\.requestFunction),
                initial: request,
                finish: proceed
            )
        } responseFunction: { response, proceed in
            executeInterceptors(
                interceptors.reversed().map(\.responseFunction),
                initial: response,
                finish: proceed
            )
        } responseMetricsFunction: { metrics, proceed in
            executeInterceptors(
                interceptors.reversed().map(\.responseMetricsFunction),
                initial: metrics,
                finish: proceed
            )
        }
    }

    /// Create a set of closures configured with all interceptors for a stream.
    ///
    /// NOTE: Interceptors are invoked in FIFO order for the request path, and in LIFO order for
    /// the response path. For example, with interceptors `[a, b, c]`:
    /// `caller -> a -> b -> c -> server`
    /// `caller <- c <- b <- a <- server`
    ///
    /// - parameter sendFunction: <#StreamFunction#>
    ///
    /// - returns: <#StreamFunction#>
    func chainStream(_ sendFunction: StreamFunction) -> StreamFunction {
        let interceptors = self.interceptors.map { $0.streamFunction() }
        return StreamFunction { request, proceed in
            executeInterceptors(
                interceptors.map(\.requestFunction),
                initial: request,
                finish: proceed
            )
        } requestDataFunction: { data, proceed in
            executeInterceptors(
                interceptors.reversed().map(\.requestDataFunction),
                initial: data,
                finish: proceed
            )
        } streamResultFunction: { result, proceed in
            executeInterceptors(
                interceptors.reversed().map(\.streamResultFunction),
                initial: result,
                finish: proceed
            )
        }
    }
}

private func executeInterceptors<T>(
    _ interceptors: [(T, @escaping (T) -> Void) -> Void],
    initial: T,
    finish: @escaping (T) -> Void
) {
    var next: (T) -> Void = { finish($0) }
    for interceptor in interceptors.reversed() {
        next = { [next] interceptedValue in interceptor(interceptedValue, next) }
    }
    next(initial)
}
