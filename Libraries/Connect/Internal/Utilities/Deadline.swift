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

import Foundation

/// Races `operation` against a deadline, canceling it if the deadline wins.
///
/// - parameter timeout: Deadline in seconds. `nil` runs `operation` with no deadline.
/// - parameter operation: The work to perform.
///
/// - returns: The result of `operation`, or `nil` if the deadline elapsed first.
func withDeadline<T: Sendable>(
    _ timeout: TimeInterval?,
    operation: @escaping @Sendable () async -> T
) async -> T? {
    guard let timeout else {
        return await operation()
    }

    // `UInt64(negativeDouble)` traps, so negative timeouts are clamped to zero.
    let nanoseconds = UInt64(max(0, timeout * 1_000_000_000))

    return await withTaskGroup(of: Optional<T>.self) { group in
        group.addTask { await operation() }
        group.addTask {
            try? await Task.sleep(nanoseconds: nanoseconds)
            return nil
        }

        // Flattens `group.next()`'s `T??` to `T?`.
        let first = await group.next().flatMap { $0 }
        // `withTaskGroup` awaits every child before returning, so this is required to avoid
        // blocking on the loser once the race is decided.
        group.cancelAll()
        return first
    }
}
