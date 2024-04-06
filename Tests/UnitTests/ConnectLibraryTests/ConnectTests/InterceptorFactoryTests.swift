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

@testable import Connect
import XCTest

private final class MockUnaryInterceptor: UnaryInterceptor {}

private final class MockStreamInterceptor: StreamInterceptor {}

private final class MockUnaryAndStreamInterceptor: UnaryInterceptor, StreamInterceptor {}

final class InterceptorFactoryTests: XCTestCase {
    private let config = ProtocolClientConfig(host: "localhost")

    func testInstantiatesUnaryInterceptorForUnary() {
        let factory = InterceptorFactory { _ in MockUnaryInterceptor() }
        XCTAssertTrue(
            factory.createUnary(with: self.config) is MockUnaryInterceptor
        )
    }

    func testInstantiatesStreamInterceptorForStream() {
        let factory = InterceptorFactory { _ in MockStreamInterceptor() }
        XCTAssertTrue(
            factory.createStream(with: self.config) is MockStreamInterceptor
        )
    }

    func testInstantiatesCombinedInterceptorForStreamAndUnary() {
        let factory = InterceptorFactory { _ in MockUnaryAndStreamInterceptor() }
        XCTAssertTrue(
            factory.createUnary(with: self.config) is MockUnaryAndStreamInterceptor
        )
        XCTAssertTrue(
            factory.createStream(with: self.config) is MockUnaryAndStreamInterceptor
        )
    }

    func testDoesNotInstantiateUnaryInterceptorForStream() {
        let factory = InterceptorFactory { _ in MockUnaryInterceptor() }
        XCTAssertNil(factory.createStream(with: self.config))
    }

    func testDoesNotInstantiateStreamInterceptorForUnary() {
        let factory = InterceptorFactory { _ in MockStreamInterceptor() }
        XCTAssertNil(factory.createUnary(with: self.config))
    }
}
