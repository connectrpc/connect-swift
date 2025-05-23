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

@testable import Connect
import Testing

private final class MockUnaryInterceptor: UnaryInterceptor {}

private final class MockStreamInterceptor: StreamInterceptor {}

private final class MockUnaryAndStreamInterceptor: UnaryInterceptor, StreamInterceptor {}

struct InterceptorFactoryTests {
    private let config = ProtocolClientConfig(host: "localhost")

    @Test("InterceptorFactory correctly instantiates UnaryInterceptor for unary request processing")
    func instantiatesUnaryInterceptorForUnary() {
        let factory = InterceptorFactory { _ in MockUnaryInterceptor() }
        #expect(
            factory.createUnary(with: self.config) is MockUnaryInterceptor
        )
    }

    @Test("InterceptorFactory correctly instantiates StreamInterceptor for stream request processing")
    func instantiatesStreamInterceptorForStream() {
        let factory = InterceptorFactory { _ in MockStreamInterceptor() }
        #expect(
            factory.createStream(with: self.config) is MockStreamInterceptor
        )
    }

    @Test("InterceptorFactory can instantiate a combined interceptor that handles both unary and stream requests")
    func instantiatesCombinedInterceptorForStreamAndUnary() {
        let factory = InterceptorFactory { _ in MockUnaryAndStreamInterceptor() }
        #expect(
            factory.createUnary(with: self.config) is MockUnaryAndStreamInterceptor
        )
        #expect(
            factory.createStream(with: self.config) is MockUnaryAndStreamInterceptor
        )
    }

    @Test("InterceptorFactory returns nil when trying to create stream interceptor from unary-only interceptor")
    func doesNotInstantiateUnaryInterceptorForStream() {
        let factory = InterceptorFactory { _ in MockUnaryInterceptor() }
        #expect(factory.createStream(with: self.config) == nil)
    }

    @Test("InterceptorFactory returns nil when trying to create unary interceptor from stream-only interceptor")
    func doesNotInstantiateStreamInterceptorForUnary() {
        let factory = InterceptorFactory { _ in MockStreamInterceptor() }
        #expect(factory.createUnary(with: self.config) == nil)
    }
}
