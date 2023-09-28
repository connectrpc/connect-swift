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
final class InterceptorChain: @unchecked Sendable {
    private let interceptors: [Interceptor]
    private(set) lazy var stream = self.interceptors.map { $0.streamFunction() }
    private(set) lazy var unary = self.interceptors.map { $0.unaryFunction() }

    /// Initialize the interceptor chain.
    ///
    /// NOTE: Exactly 1 chain is expected to be instantiated for a single request or stream.
    ///
    /// - parameter interceptors: Closures that should be called to create interceptors.
    /// - parameter config: Config to use for setting up interceptors.
    init(interceptors: [InterceptorInitializer], config: ProtocolClientConfig) {
        self.interceptors = interceptors.map { initialize in initialize(config) }
    }

    /// <#execute(_:initial:finish:)#>
    ///
    /// - parameter interceptors: <#[(T, @escaping (T) -> Void) -> Void]#>
    /// - parameter initial: <#T#>
    /// - parameter finish: <#@escaping (T) -> Void#>
    func execute<T>(
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
}
