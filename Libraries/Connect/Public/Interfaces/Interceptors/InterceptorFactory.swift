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

/// Factory for creating interceptors. Invoked once per request/stream to produce interceptor
/// instances.
///
/// This wrapper also captures the underlying type of the interceptor class, allowing the factory
/// to only instantiate instances when necessary (for example, a stream-only interceptor should not
/// be instantiated for a unary request).
public struct InterceptorFactory: Sendable {
    private let factory: @Sendable (ProtocolClientConfig) -> Interceptor
    private let interceptorType: Interceptor.Type

    /// Initialize a new factory which may be used to produce instances of an interceptor type.
    ///
    /// - parameter factory: Closure to use to produce a new interceptor instance given a config.
    public init<T: Interceptor>(factory: @escaping @Sendable (ProtocolClientConfig) -> T) {
        self.factory = factory
        self.interceptorType = T.self
    }

    // MARK: - Internal

    func createUnary(with config: ProtocolClientConfig) -> UnaryInterceptor? {
        if self.interceptorType.self is UnaryInterceptor.Type {
            return self.factory(config) as? UnaryInterceptor
        }
        return nil
    }

    func createStream(with config: ProtocolClientConfig) -> StreamInterceptor? {
        if self.interceptorType.self is StreamInterceptor.Type {
            return self.factory(config) as? StreamInterceptor
        }
        return nil
    }
}
