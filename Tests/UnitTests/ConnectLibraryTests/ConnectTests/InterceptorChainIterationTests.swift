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

struct InterceptorChainIterationTests {
    @Test("InterceptorChain executes non-failing interceptors in first-in-first-out order")
    func executingNonFailing() {
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
        #expect(result.value == "ab")
    }

    @Test("InterceptorChain executes non-failing interceptors in reverse order when firstInFirstOut is false")
    func executingNonFailingReversed() {
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
        #expect(result.value == "ba")
    }

    @Test("InterceptorChain can execute linked interceptors with a transform function between them")
    func executingLinkedNonFailing() {
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
        #expect(result.value == 12 + 1 + 3)
    }

    @Test("InterceptorChain executes failable interceptors successfully when no errors occur")
    func executingFailableWithoutError() throws {
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
        let unwrapped = try result.value?.get()
        #expect(unwrapped == "ab")
    }

    @Test("InterceptorChain executes failable interceptors in reverse order when firstInFirstOut is false")
    func executingFailableWithoutErrorReversed() throws {
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
        let unwrapped = try result.value?.get()
        #expect(unwrapped == "ba")
    }

    @Test("InterceptorChain stops execution and propagates error when an interceptor fails")
    func executingFailableWithError() {
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
        #expect(throws: (any Error).self) {
            try result.value?.get()
        }
    }

    @Test("InterceptorChain executes linked failable interceptors successfully when no errors occur")
    func executingLinkedFailableWithoutError() throws {
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
        let unwrapped = try result.value?.get()
        #expect(unwrapped == 12 + 1 + 3)
    }

    @Test("InterceptorChain stops linked execution when error occurs in first iteration of interceptors")
    func executingLinkedFailableWithErrorOnFirstIteration() {
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
        #expect(throws: (any Error).self) {
            try result.value?.get()
        }
    }

    @Test("InterceptorChain stops linked execution when error occurs in transform function")
    func executingLinkedFailableWithErrorOnTransform() {
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
        #expect(throws: (any Error).self) {
            try result.value?.get()
        }
    }

    @Test("InterceptorChain stops linked execution when error occurs in second iteration of interceptors")
    func executingLinkedFailableWithErrorOnSecondIteration() {
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
        #expect(throws: (any Error).self) {
            try result.value?.get()
        }
    }
}
