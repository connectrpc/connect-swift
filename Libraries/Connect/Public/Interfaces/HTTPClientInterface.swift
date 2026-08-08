// Copyright 2022-2025 The Connect Authors
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

/// Interface for a client that performs underlying HTTP requests and streams with primitive types.
public protocol HTTPClientInterface: Sendable {
    /// Perform a unary HTTP request.
    ///
    /// This closure-based version intentionally has **no** default implementation: the `async`
    /// spelling below defaults to forwarding here, and defaulting both would make a type that
    /// implements neither recurse forever.
    ///
    /// - parameter request: The outbound request headers and data.
    /// - parameter onMetrics: Closure that should be called when metrics are finalized. This may be
    ///                        called before or after `onResponse`.
    /// - parameter onResponse: Closure that should be called when a response is received.
    ///
    /// - returns: A type which can be used to cancel the outbound request.
    @discardableResult
    func unary(
        request: HTTPRequest<Data?>,
        onMetrics: @escaping @Sendable (HTTPMetrics) -> Void,
        onResponse: @escaping @Sendable (HTTPResponse) -> Void
    ) -> Cancelable

    /// Perform a unary HTTP request.
    ///
    /// This is the spelling the library invokes. The default implementation forwards to the
    /// closure-based version above and cancels the returned `Cancelable` if the calling task is
    /// canceled. Implement this directly to skip that bridge.
    ///
    /// - parameter request: The outbound request headers and data.
    /// - parameter onMetrics: Closure that should be called when metrics are finalized. This may be
    ///                        called before or after this function returns, which is why metrics
    ///                        cannot ride the return value.
    ///
    /// - returns: The response received from the server.
    func unary(
        request: HTTPRequest<Data?>,
        onMetrics: @escaping @Sendable (HTTPMetrics) -> Void
    ) async -> HTTPResponse

    /// Initialize a new HTTP stream.
    ///
    /// - parameter request: The request headers to use for starting the stream.
    /// - parameter responseCallbacks: Set of callbacks that should be invoked by the HTTP client
    ///                                when response data is received from the server.
    ///
    /// - returns: Set of callbacks which can be called to send data over the stream or to close it.
    func stream(
        request: HTTPRequest<Data?>,
        responseCallbacks: ResponseCallbacks
    ) -> RequestCallbacks<Data>
}

extension HTTPClientInterface {
    public func unary(
        request: HTTPRequest<Data?>,
        onMetrics: @escaping @Sendable (HTTPMetrics) -> Void
    ) async -> HTTPResponse {
        let cancelable = Locked<Cancelable?>(nil)
        return await withTaskCancellationHandler {
            await withSingleResume { resume in
                // A cancelation landing between `unary()` returning and this assignment is missed
                // (a preexisting race, not new here). Upgrade to an atomic (cancelable,
                // isCancelled) read-modify-write if it ever shows up in practice.
                cancelable.value = self.unary(
                    request: request, onMetrics: onMetrics, onResponse: resume
                )
            }
        } onCancel: {
            cancelable.value?.cancel()
        }
    }
}
