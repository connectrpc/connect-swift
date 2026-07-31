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

struct DeadlineTests {
    private static let shortDeadline: TimeInterval = 0.05
    private static let longDeadline: TimeInterval = 30.0
    private static let operationNanoseconds: UInt64 = 500_000_000

    @Test
    func returnsValueWhenOperationBeatsDeadline() async {
        let result = await withDeadline(Self.longDeadline) { "finished" }
        #expect(result == "finished")
    }

    @Test
    func returnsNilWhenDeadlineElapsesFirst() async {
        let result: String? = await withDeadline(Self.shortDeadline) {
            try? await Task.sleep(nanoseconds: Self.operationNanoseconds)
            return "too late"
        }
        #expect(result == nil)
    }

    @Test
    func runsWithoutDeadlineWhenTimeoutIsNil() async {
        let result = await withDeadline(nil) { 42 }
        #expect(result == 42)
    }

    @Test
    func clampsNegativeTimeoutToZero() async {
        let result: String? = await withDeadline(-1.0) {
            try? await Task.sleep(nanoseconds: Self.operationNanoseconds)
            return "too late"
        }
        #expect(result == nil)
    }

    @Test
    func cancelsOperationWhenDeadlineWins() async {
        let observedCancelation = Locked(false)

        _ = await withDeadline(Self.shortDeadline) { () async -> String in
            try? await Task.sleep(nanoseconds: Self.operationNanoseconds)
            observedCancelation.value = Task.isCancelled
            return "too late"
        }

        #expect(observedCancelation.value)
    }

    @Test
    func returnsPromptlyWhenOperationWins() async {
        // Regression check: `withTaskGroup` awaits every child before returning, so a missing
        // `cancelAll()` would make this block for the full `longDeadline` instead.
        let start = Date()
        let result = await withDeadline(Self.longDeadline) { "finished" }

        #expect(result == "finished")
        #expect(Date().timeIntervalSince(start) < 1.0)
    }
}
