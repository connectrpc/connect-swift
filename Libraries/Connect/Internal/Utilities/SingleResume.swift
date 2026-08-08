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
import os.log

/// Bridges a completion-closure API to `async`, tolerating a completion that fires more than once.
///
/// - parameter body: Closure invoked with the completion closure to hand to the wrapped API.
/// - returns: The value passed to the first invocation of the completion closure.
func withSingleResume<Value: Sendable>(
    _ body: (@escaping @Sendable (Value) -> Void) -> Void
) async -> Value {
    return await withCheckedContinuation { continuation in
        let hasResumed = Locked(false)
        body { value in
            let shouldResume = hasResumed.perform { hasResumed -> Bool in
                if hasResumed {
                    return false
                }
                hasResumed = true
                return true
            }
            guard shouldResume else {
                os_log(
                    .fault,
                    "Completion closure was invoked more than once; ignoring the duplicate value."
                )
                return
            }
            // Deliberately outside the lock: `Locked` is backed by `os_unfair_lock`, and resuming
            // a continuation while holding it risks priority inversion.
            continuation.resume(returning: value)
        }
    }
}
