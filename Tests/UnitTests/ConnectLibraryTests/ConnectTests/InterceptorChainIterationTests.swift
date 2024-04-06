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

final class InterceptorChainIterationTests: XCTestCase {
    func testExecutingNonFailing() {
        let initialValue = ""
        let result = Locked(initialValue)
        let chain = InterceptorChain([Void]())
        chain.executeInterceptors(
            [
                { value, proceed in proceed(value + "a") },
                { value, proceed in proceed(value + "b") },
            ],
            firstInFirstOut: true,
            initial: initialValue,
            finish: { result.value = $0 }
        )
        XCTAssertEqual(result.value, "ab")
    }

    func testExecutingNonFailingReversed() {
        let initialValue = ""
        let result = Locked(initialValue)
        let chain = InterceptorChain([Void]())
        chain.executeInterceptors(
            [
                { value, proceed in proceed(value + "a") },
                { value, proceed in proceed(value + "b") },
            ],
            firstInFirstOut: false,
            initial: initialValue,
            finish: { result.value = $0 }
        )
        XCTAssertEqual(result.value, "ba")
    }

    func testExecutingLinkedNonFailing() {
        let result = Locked(0)
        let chain = InterceptorChain([Void]())
        chain.executeLinkedInterceptors(
            [
                { value, proceed in proceed(value + "1") },
                { value, proceed in proceed(value + "2") },
            ],
            firstInFirstOut: true,
            initial: "",
            transform: { value1, proceed in proceed(Int(value1)!) },
            then: [
                { value, proceed in proceed(value + 1) },
                { value, proceed in proceed(value + 3) },
            ],
            finish: { result.value = $0 }
        )
        XCTAssertEqual(result.value, 12 + 1 + 3)
    }

    func testExecutingFailableWithoutError() {
        let result = Locked<Result<String, ConnectError>?>(nil)
        let chain = InterceptorChain([Void]())
        chain.executeInterceptorsAndStopOnFailure(
            [
                { value, proceed in proceed(.success(value + "a")) },
                { value, proceed in proceed(.success(value + "b")) },
            ],
            firstInFirstOut: true,
            initial: "",
            finish: { result.value = $0 }
        )
        XCTAssertEqual(try? result.value?.get(), "ab")
    }

    func testExecutingFailableWithoutErrorReversed() {
        let result = Locked<Result<String, ConnectError>?>(nil)
        let chain = InterceptorChain([Void]())
        chain.executeInterceptorsAndStopOnFailure(
            [
                { value, proceed in proceed(.success(value + "a")) },
                { value, proceed in proceed(.success(value + "b")) },
            ],
            firstInFirstOut: false,
            initial: "",
            finish: { result.value = $0 }
        )
        XCTAssertEqual(try? result.value?.get(), "ba")
    }

    func testExecutingFailableWithError() {
        let result = Locked<Result<String, ConnectError>?>(nil)
        let chain = InterceptorChain([Void]())
        chain.executeInterceptorsAndStopOnFailure(
            [
                { _, proceed in
                    proceed(.failure(.from(
                        code: .unknown, headers: nil, trailers: nil, source: nil
                    )))
                },
                { value, proceed in proceed(.success(value + "b")) },
            ],
            firstInFirstOut: true,
            initial: "",
            finish: { result.value = $0 }
        )
        XCTAssertThrowsError(try result.value?.get())
    }

    func testExecutingLinkedFailableWithoutError() {
        let result = Locked<Result<Int, ConnectError>?>(nil)
        let chain = InterceptorChain([Void]())
        chain.executeLinkedInterceptorsAndStopOnFailure(
            [
                { value, proceed in proceed(.success(value + "1")) },
                { value, proceed in proceed(.success(value + "2")) },
            ],
            firstInFirstOut: true,
            initial: "",
            transform: { value1, proceed in proceed(.success(Int(value1)!)) },
            then: [
                { value, proceed in proceed(.success(value + 1)) },
                { value, proceed in proceed(.success(value + 3)) },
            ],
            finish: { result.value = $0 }
        )
        XCTAssertEqual(try? result.value?.get(), 12 + 1 + 3)
    }

    func testExecutingLinkedFailableWithErrorOnFirstIteration() {
        let result = Locked<Result<Int, ConnectError>?>(nil)
        let chain = InterceptorChain([Void]())
        chain.executeLinkedInterceptorsAndStopOnFailure(
            [
                { _, proceed in
                    proceed(.failure(.from(
                        code: .unknown, headers: nil, trailers: nil, source: nil
                    )))
                },
                { value, proceed in proceed(.success(value + "2")) },
            ],
            firstInFirstOut: true,
            initial: "",
            transform: { value1, proceed in proceed(.success(Int(value1)!)) },
            then: [
                { value, proceed in proceed(.success(value + 1)) },
                { value, proceed in proceed(.success(value + 3)) },
            ],
            finish: { result.value = $0 }
        )
        XCTAssertThrowsError(try result.value?.get())
    }

    func testExecutingLinkedFailableWithErrorOnTransform() {
        let result = Locked<Result<Int, ConnectError>?>(nil)
        let chain = InterceptorChain([Void]())
        chain.executeLinkedInterceptorsAndStopOnFailure(
            [
                { value, proceed in proceed(.success(value + "1")) },
                { value, proceed in proceed(.success(value + "2")) },
            ],
            firstInFirstOut: true,
            initial: "",
            transform: { _, proceed in
                proceed(.failure(.from(
                    code: .unknown, headers: nil, trailers: nil, source: nil
                )))
            },
            then: [
                { value, proceed in proceed(.success(value + 1)) },
                { value, proceed in proceed(.success(value + 3)) },
            ],
            finish: { result.value = $0 }
        )
        XCTAssertThrowsError(try result.value?.get())
    }

    func testExecutingLinkedFailableWithErrorOnSecondIteration() {
        let result = Locked<Result<Int, ConnectError>?>(nil)
        let chain = InterceptorChain([Void]())
        chain.executeLinkedInterceptorsAndStopOnFailure(
            [
                { value, proceed in proceed(.success(value + "1")) },
                { value, proceed in proceed(.success(value + "2")) },
            ],
            firstInFirstOut: true,
            initial: "",
            transform: { value1, proceed in proceed(.success(Int(value1)!)) },
            then: [
                { _, proceed in
                    proceed(.failure(.from(
                        code: .unknown, headers: nil, trailers: nil, source: nil
                    )))
                },
                { value, proceed in proceed(.success(value + 3)) },
            ],
            finish: { result.value = $0 }
        )
        XCTAssertThrowsError(try result.value?.get())
    }
}
