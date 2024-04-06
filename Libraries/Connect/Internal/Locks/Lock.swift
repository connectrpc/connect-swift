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

import Foundation

/// Internal implementation of a lock. Wraps usage of `os_unfair_lock`.
final class Lock: Sendable {
    private let underlyingLock: UnsafeMutablePointer<os_unfair_lock>

    init() {
        // Reasoning for allocating here: http://www.russbishop.net/the-law
        // When iOS 15 support is dropped, `OSAllocatedUnfairLock` should be used.
        self.underlyingLock = .allocate(capacity: 1)
        self.underlyingLock.initialize(to: os_unfair_lock())
    }

    /// Perform an action within the context of the lock.
    ///
    /// - parameter action: Closure to be executed in the context of the lock.
    ///
    /// - returns: The result of the closure.
    func perform<T>(action: @escaping () -> T) -> T {
        os_unfair_lock_lock(self.underlyingLock)
        defer { os_unfair_lock_unlock(self.underlyingLock) }
        return action()
    }
}
