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
import Foundation
import Testing

private typealias TestMessage = Connectrpc_Conformance_V1_UnaryResponse

struct UnaryAsyncWrapperTests {
    /// `UnaryAsyncWrapper` may only resume its continuation once; a second resume is a hard trap
    /// (`SWIFT TASK CONTINUATION MISUSE`), so a regression here surfaces as a crashed test process
    /// rather than a failed expectation.
    ///
    /// This is a race, and any single iteration proves nothing - the repetition is the test.
    @Test
    func concurrentDuplicateCallbacksResumeContinuationOnce() async {
        for _ in 0..<100 {
            let invocations = Locked(0)
            let wrapper = UnaryAsyncWrapper<TestMessage> { completion in
                // Release both callbacks at a common deadline so they land as close to
                // simultaneously as the hardware allows.
                let releaseTime = DispatchTime.now() + .milliseconds(5)
                for _ in 0..<2 {
                    DispatchQueue.global().async {
                        while DispatchTime.now() < releaseTime {}
                        invocations.perform { $0 += 1 }
                        completion(ResponseMessage(result: .success(TestMessage())))
                    }
                }
                return Cancelable {}
            }

            let response = await wrapper.send()
            #expect(response.code == .ok)
            #expect(response.message != nil)

            // `send()` returns as soon as the first callback wins, so wait for the loser to
            // finish. Asserting on this ensures the test fails loudly if the duplicate callback
            // was never actually delivered, rather than passing vacuously.
            while invocations.value < 2 {
                await Task.yield()
            }
            #expect(invocations.value == 2)
        }
    }

    @Test
    func singleCallbackResumesWithItsResponse() async {
        let invocations = Locked(0)
        let expectedMessage = TestMessage.with { $0.payload.data = Data(repeating: 42, count: 4) }
        let wrapper = UnaryAsyncWrapper<TestMessage> { completion in
            invocations.perform { $0 += 1 }
            completion(ResponseMessage(code: .ok, result: .success(expectedMessage)))
            return Cancelable {}
        }

        let response = await wrapper.send()
        #expect(invocations.value == 1)
        #expect(response.code == .ok)
        #expect(response.error == nil)
        #expect(response.message == expectedMessage)
    }

    /// `UnaryAsyncWrapper.cancelable` is assigned only after `sendUnary` returns, and the actor's
    /// serialization is what keeps a cancelation arriving in that window from being dropped. This
    /// locks in that behavior so a future refactor cannot regress it silently.
    @Test
    func cancelationDuringDispatchReachesCancelable() async {
        for _ in 0..<50 {
            let didCancel = Locked(false)
            let dispatchStarted = Locked(false)
            let wrapper = UnaryAsyncWrapper<TestMessage> { completion in
                // Signal that `sendUnary` is executing, then stall so the cancelation below
                // lands before `cancelable` has been assigned.
                dispatchStarted.value = true
                Thread.sleep(forTimeInterval: 0.005)

                // Fallback response so that a dropped cancelation fails an expectation instead
                // of hanging the test forever.
                DispatchQueue.global().asyncAfter(deadline: .now() + .milliseconds(250)) {
                    completion(ResponseMessage(code: .ok, result: .success(TestMessage())))
                }

                return Cancelable {
                    didCancel.value = true
                    completion(ResponseMessage(
                        code: .canceled, result: .failure(ConnectError.canceled())
                    ))
                }
            }

            let task = Task { await wrapper.send() }
            while !dispatchStarted.value {
                await Task.yield()
            }
            task.cancel()

            let response = await task.value
            #expect(didCancel.value)
            #expect(response.code == .canceled)
            #expect(response.error?.code == .canceled)
        }
    }
}
