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
    @available(iOS 13, *)
    @Test
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

    @available(iOS 13, *)
    @Test
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

    @available(iOS 13, *)
    @Test
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

    @available(iOS 13, *)
    @Test
    func executingFailableWithoutError() {
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
        #expect((try? result.value?.get()) == "ab")
    }

    @available(iOS 13, *)
    @Test
    func executingFailableWithoutErrorReversed() {
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
        #expect((try? result.value?.get()) == "ba")
    }

    @available(iOS 13, *)
    @Test
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
        #expect(throws: ConnectError.self) { try result.value?.get() }
    }

    @available(iOS 13, *)
    @Test
    func executingLinkedFailableWithoutError() {
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
        #expect((try? result.value?.get()) == 12 + 1 + 3)
    }

    @available(iOS 13, *)
    @Test
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
        #expect(throws: ConnectError.self) { try result.value?.get() }
    }

    @available(iOS 13, *)
    @Test
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
        #expect(throws: ConnectError.self) { try result.value?.get() }
    }

    @available(iOS 13, *)
    @Test
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
        #expect(throws: ConnectError.self) { try result.value?.get() }
    }
}
