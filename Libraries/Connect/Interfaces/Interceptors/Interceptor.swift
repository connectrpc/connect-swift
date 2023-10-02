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

/// Interceptors can be registered with clients as a way to observe and/or alter outbound requests
/// and inbound responses.
///
/// Interceptors are expected to be instantiated **once per request or stream**.
///
/// Each interceptor has the opportunity to perform asynchronous work before passing a potentially
/// altered value to the next interceptor in the chain. When the end of the chain is reached, the
/// final value is passed to the networking client where it is sent to the server or to the calling
/// client.
///
/// Interceptors may also fail outbound requests before they're sent, thus preventing subsequent
/// interceptors from being invoked and returning a specified error back to the original caller.
///
/// Interceptors are closure-based and are passed both the current value and a closure which
/// should be called to resume the interceptor chain. Propagation will not continue until
/// this closure is called. Additional values may still be passed to a given interceptor even
/// though it has not yet continued the chain. For example:
/// - Request is sent
/// - Response headers are received, and an interceptor pauses the chain while processing
/// - First chunk of streamed data is received, and the interceptor receives this value immediately
/// - Interceptor is expected to resume headers first, followed by data
///
/// Implementations should be thread-safe (hence the `Sendable` requirement on interceptor
/// closures), as closures can be invoked from different threads during the span of a request or
/// stream due to the asynchronous nature of other interceptors which may be present in the chain.
///
/// Interceptors can also be written using `async/await` by incorporating a `Task`. For example:
///
/// ```
/// final class AsyncInterceptor: Interceptor, Sendable {
///    func unaryFunction() -> UnaryFunction {
///        return .init { request, proceed in
///            Task {
///                proceed(await self.handleRequest(request))
///            }
///        } responseFunction: { response, proceed in
///            Task {
///                proceed(await self.handleUnaryResponse(response))
///            }
///        } responseMetricsFunction: { metrics, proceed in
///            Task {
///                proceed(await self.handleUnaryResponseMetrics(metrics))
///            }
///        }
///    }
///
///    func streamFunction() -> StreamFunction {...}
/// }
/// ```
public protocol Interceptor {
    /// Invoked when a unary request is started. Provides a set of closures that will be called
    /// as the request progresses, allowing the interceptor to read/alter request/response data.
    ///
    /// - returns: A new set of closures which can be used to read/alter request/response data.
    func unaryFunction() -> UnaryFunction

    /// Invoked when a stream is started. Provides a set of closures that will be called
    /// as the stream progresses, allowing the interceptor to read/alter request/response data.
    ///
    /// NOTE: Some closures may be called multiple times as the stream progresses
    /// (for example, as data chunks are sent/received over a bidirectional stream).
    ///
    /// A guarantee is provided that each data chunk will contain 1 full message
    /// (for Connect and gRPC, this includes the prefix and message
    /// length bytes, followed by the actual message data).
    ///
    /// - returns: A new set of closures which can be used to read/alter request/response data.
    func streamFunction() -> StreamFunction
}
