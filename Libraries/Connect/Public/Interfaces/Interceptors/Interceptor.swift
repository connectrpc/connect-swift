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

/// Interceptors are a powerful way to observe and mutate outbound and inbound
/// headers, data, trailers, typed messages, and errors both for unary APIs and streams.
///
/// Each interceptor is instantiated **once per request or stream** and
/// provides a set of functions that are invoked by the client during the lifecycle
/// of that call. Each function allows the interceptor to observe and store
/// state, as well as to mutate outbound or inbound content. Interceptors have the ability to
/// interact with both typed messages (request messages prior to serialization and response
/// messages after deserialization) and raw data.
///
/// Every interceptor has the opportunity to perform asynchronous work before passing a potentially
/// altered value to the next interceptor in the chain. When the end of the chain is reached, the
/// final value is passed to the networking client, where it is sent to the server
/// (outbound request) or to the caller (inbound response).
///
/// Interceptors may also fail outbound requests before they are sent; subsequent
/// interceptors in the chain will not be invoked, and the error will be returned to the
/// original caller.
///
/// Interceptors are invoked in FIFO order on the request path, and in LIFO order on the
/// response path. For example:
///
/// Client -> A -> B -> C -> D -> Server
/// Client <- D <- C <- B <- A <- Server
///
/// Interceptors receive both the current value and a closure that
/// should be called to resume the interceptor chain. Propagation will not continue until
/// this closure is invoked. Additional values may still be passed to a given interceptor even
/// though it has not yet continued the chain with a previous value. For example:
///
/// 1. A request is sent.
/// 2. Response headers are received, and an interceptor pauses the chain while processing them.
/// 3. The first chunk of streamed response data is received, and the interceptor is invoked with
///    this value.
/// 4. The interceptor is expected to resume with headers first, and then with data after.
///
/// Implementations should be thread-safe (hence the `Sendable` requirements),
/// as functions can be invoked from different threads during the span of a request or
/// stream due to the asynchronous nature of other interceptors which may be present in the chain.
///
/// This high-level protocol encompasses characteristics shared by unary and stream interceptors.
/// Implementations can interact with unary requests, streams, or both. See the
/// derived `UnaryInterceptor` and `StreamInterceptor` protocols for additional details.
public protocol Interceptor: AnyObject, Sendable {
    /// Observe and/or mutate response metrics for a unary request or stream.
    ///
    /// - parameter metrics: Metrics containing data about the completed request/stream.
    /// - parameter proceed: Closure which must be called to pass (potentially altered) data to the
    ///                      next interceptor.
    @Sendable
    func handleResponseMetrics(
        _ metrics: HTTPMetrics,
        proceed: @escaping @Sendable (HTTPMetrics) -> Void
    )
}

extension Interceptor {
    @Sendable
    public func handleResponseMetrics(
        _ metrics: HTTPMetrics,
        proceed: @escaping @Sendable (HTTPMetrics) -> Void
    ) {
        proceed(metrics)
    }
}
