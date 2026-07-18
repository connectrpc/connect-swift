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

    @available(iOS 13, *)
    @Test
    func instantiatesUnaryInterceptorForUnary() {
        let factory = InterceptorFactory { _ in MockUnaryInterceptor() }
        #expect(
            factory.createUnary(with: self.config) is MockUnaryInterceptor
        )
    }

    @available(iOS 13, *)
    @Test
    func instantiatesStreamInterceptorForStream() {
        let factory = InterceptorFactory { _ in MockStreamInterceptor() }
        #expect(
            factory.createStream(with: self.config) is MockStreamInterceptor
        )
    }

    @available(iOS 13, *)
    @Test
    func instantiatesCombinedInterceptorForStreamAndUnary() {
        let factory = InterceptorFactory { _ in MockUnaryAndStreamInterceptor() }
        #expect(
            factory.createUnary(with: self.config) is MockUnaryAndStreamInterceptor
        )
        #expect(
            factory.createStream(with: self.config) is MockUnaryAndStreamInterceptor
        )
    }

    @available(iOS 13, *)
    @Test
    func doesNotInstantiateUnaryInterceptorForStream() {
        let factory = InterceptorFactory { _ in MockUnaryInterceptor() }
        #expect(factory.createStream(with: self.config) == nil)
    }

    @available(iOS 13, *)
    @Test
    func doesNotInstantiateStreamInterceptorForUnary() {
        let factory = InterceptorFactory { _ in MockStreamInterceptor() }
        #expect(factory.createUnary(with: self.config) == nil)
    }
}
