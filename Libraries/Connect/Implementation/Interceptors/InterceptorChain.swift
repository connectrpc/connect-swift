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
final class InterceptorChain<T: Sendable>: Sendable {
    let interceptors: [T]

    init(_ interceptors: [T]) {
        self.interceptors = interceptors
    }

    /// <#executeInterceptors(_:firstInFirstOut:initial:)#>
    ///
    /// - parameter functions: <#[@Sendable (Value) -> Value]#>
    /// - parameter firstInFirstOut: <#Bool#>
    /// - parameter initial: <#Value#>
    ///
    /// - returns: <#Value#>
    func executeInterceptors<Value>(
        _ functions: [@Sendable (Value) -> Value],
        firstInFirstOut: Bool,
        initial: Value
    ) -> Value {
        let functions = firstInFirstOut ? functions.reversed() : functions
        var value = initial
        for function in functions {
            value = function(value)
        }
        return value
    }

    /// Invoke each of the interceptors, waiting for a given interceptor to complete before passing
    /// the resulting value to the next interceptor and finally invoking `finish` with the final
    /// value.
    ///
    /// - parameter functions: <#[@Sendable (Value, @escaping @Sendable (Value) -> Void) -> Void]#>
    /// - parameter firstInFirstOut: If true, interceptors will be invoked in the order they were
    ///                              originally registered. If false, the order will be reversed.
    /// - parameter initial: The initial value to pass to the first interceptor.
    /// - parameter finish: Closure to call with the final value after each interceptor has finished
    ///                     processing.
    func executeInterceptors<Value>(
        _ functions: [@Sendable (Value, @escaping @Sendable (Value) -> Void) -> Void],
        firstInFirstOut: Bool,
        initial: Value,
        finish: @escaping @Sendable (Value) -> Void
    ) {
        let functions = firstInFirstOut ? functions.reversed() : functions
        var next: @Sendable (Value) -> Void = { finish($0) }
        for function in functions {
            next = { [next] interceptedValue in function(interceptedValue, next) }
        }
        next(initial)
    }

    /// Invoke each of the interceptors, waiting for a given interceptor to complete before passing
    /// the resulting value to the next interceptor and finally invoking `finish` with the final
    /// value.
    ///
    /// **If an interceptor returns a `Result.failure`, the chain will be terminated immediately
    /// without invoking additional interceptors, and the failure result will be returned to the
    /// caller.**
    ///
    /// - parameter functions: <#[@Sendable (Value, @escaping @Sendable (Value) -> Void) -> Void]#>
    /// - parameter firstInFirstOut: If true, interceptors will be invoked in the order they were
    ///                              originally registered. If false, the order will be reversed.
    /// - parameter initial: The initial value to pass to the first interceptor.
    /// - parameter finish: Closure to call with the final value either after each interceptor has
    ///                     finished processing or when one returns a `Result.failure`.
    func executeInterceptorsAndStopOnFailure<Value>(
        _ functions: [
            @Sendable (Value, @escaping @Sendable (Result<Value, ConnectError>) -> Void) -> Void
        ],
        firstInFirstOut: Bool,
        initial: Value,
        finish: @escaping @Sendable (Result<Value, ConnectError>) -> Void
    ) {
        let functions = firstInFirstOut ? functions.reversed() : functions
        var next: @Sendable (Result<Value, ConnectError>) -> Void = { finish($0) }
        for function in functions {
            next = { [next] result in
                switch result {
                case .success(let interceptedValue):
                    function(interceptedValue, next)
                case .failure:
                    finish(result)
                }
            }
        }
        next(.success(initial))
    }
}
