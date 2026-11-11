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

struct TimeoutTimerTests {
    /// Generous multiple of the 50ms deadline configured by `makeConfig()`. `confirmation()`
    /// validates its count when the body returns rather than waiting, so the body must outlast
    /// the deadline on its own.
    private static let waitNanoseconds: UInt64 = 500_000_000

    @Test
    func returnsNilWhenTimeoutIsNotConfigured() {
        #expect(TimeoutTimer(config: ProtocolClientConfig(host: "http://localhost")) == nil)
    }

    @Test
    func firesAfterTheDeadline() async throws {
        let timer = try #require(TimeoutTimer(config: Self.makeConfig()))
        let timedOutWhenInvoked = Locked<Bool?>(nil)

        await confirmation("Deadline callback runs") { confirmed in
            timer.start {
                timedOutWhenInvoked.value = timer.timedOut
                confirmed()
            }
            try? await Task.sleep(nanoseconds: Self.waitNanoseconds)
        }

        #expect(timer.timedOut)
        // `ProtocolClient` reads `timedOut` from within the cancelation this callback triggers.
        #expect(timedOutWhenInvoked.value == true)
    }

    @Test
    func cancelAfterStartPreventsFiring() async throws {
        let timer = try #require(TimeoutTimer(config: Self.makeConfig()))

        await confirmation("Deadline callback never runs", expectedCount: 0) { confirmed in
            timer.start { confirmed() }
            timer.cancel()
            try? await Task.sleep(nanoseconds: Self.waitNanoseconds)
        }

        #expect(!timer.timedOut)
    }

    @Test
    func cancelBeforeStartPreventsFiring() async throws {
        let timer = try #require(TimeoutTimer(config: Self.makeConfig()))

        await confirmation("Deadline callback never runs", expectedCount: 0) { confirmed in
            timer.cancel()
            timer.start { confirmed() }
            try? await Task.sleep(nanoseconds: Self.waitNanoseconds)
        }

        #expect(!timer.timedOut)
    }

    @Test
    func deallocationPreventsFiring() async throws {
        try await confirmation("Deadline callback never runs", expectedCount: 0) { confirmed in
            do {
                let timer = try #require(TimeoutTimer(config: Self.makeConfig()))
                timer.start { confirmed() }
            }

            try? await Task.sleep(nanoseconds: Self.waitNanoseconds)
        }
    }

    private static func makeConfig() -> ProtocolClientConfig {
        return ProtocolClientConfig(host: "http://localhost", timeout: 0.05)
    }
}
