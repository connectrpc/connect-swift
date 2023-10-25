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

    func executeLinkedInterceptors<Value1, Value2>(
        _ value1Functions: [@Sendable (Value1, @escaping @Sendable (Value1) -> Void) -> Void],
        firstInFirstOut: Bool,
        initial: Value1,
        transform: @escaping @Sendable (Value1, @escaping @Sendable (Value2) -> Void) -> Void,
        then value2Functions: [@Sendable (Value2, @escaping @Sendable (Value2) -> Void) -> Void],
        finish: @escaping @Sendable (Value2) -> Void
    ) {
        self.executeInterceptors(
            value1Functions,
            firstInFirstOut: firstInFirstOut,
            initial: initial
        ) { interceptedValue in
            transform(interceptedValue) { transformedValue in
                self.executeInterceptors(
                    value2Functions,
                    firstInFirstOut: firstInFirstOut,
                    initial: transformedValue,
                    finish: finish
                )
            }
        }
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

    func executeLinkedInterceptorsAndStopOnFailure<Value1, Value2>(
        _ value1Functions: [
            @Sendable (Value1, @escaping @Sendable (Result<Value1, ConnectError>) -> Void) -> Void
        ],
        firstInFirstOut: Bool,
        initial: Value1,
        transform: @escaping @Sendable (
            Value1, @escaping @Sendable (Result<Value2, ConnectError>) -> Void
        ) -> Void,
        then value2Functions: [
            @Sendable (Value2, @escaping @Sendable (Result<Value2, ConnectError>) -> Void) -> Void
        ],
        finish: @escaping @Sendable (Result<Value2, ConnectError>) -> Void
    ) {
        self.executeInterceptorsAndStopOnFailure(
            value1Functions,
            firstInFirstOut: firstInFirstOut,
            initial: initial
        ) { interceptedResult in
            switch interceptedResult {
            case .success(let interceptedValue):
                transform(interceptedValue) { transformedResult in
                    switch transformedResult {
                    case .success(let transformedValue):
                        self.executeInterceptorsAndStopOnFailure(
                            value2Functions,
                            firstInFirstOut: firstInFirstOut,
                            initial: transformedValue,
                            finish: finish
                        )
                    case .failure(let error):
                        finish(.failure(error))
                    }
                }
            case .failure(let error):
                finish(.failure(error))
            }
        }
    }
}
