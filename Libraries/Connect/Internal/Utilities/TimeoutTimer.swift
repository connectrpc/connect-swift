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

final class TimeoutTimer: Sendable {
    private let hasTimedOut: Locked<Bool>
    private let onTimeout: Locked<(@Sendable () -> Void)?>
    private let queue = DispatchQueue(label: "connectrpc.Timeout")
    private let timeout: TimeInterval
    // Safety: `nonisolated(unsafe)` because `DispatchWorkItem` carries no `Sendable`
    // conformance in the SDK. The item is created once in `init` and never reassigned;
    // the only operations performed on it are `cancel()` and a single `asyncAfter`
    // enqueue, both of which are thread-safe.
    nonisolated(unsafe) private let workItem: DispatchWorkItem

    var timedOut: Bool {
        return self.hasTimedOut.value
    }

    init?(config: ProtocolClientConfig) {
        guard let timeout = config.timeout else {
            return nil
        }

        // Locals are created first and captured by the work item so that it does
        // not retain `self` (approximating the previous `[weak self]` lifetime
        // semantics: `deinit` cancels the not-yet-started work item). One narrow
        // difference from `[weak self]`: if the work item has already started
        // executing when the last owner releases the timer, it now still invokes
        // `onTimeout` (previously the nil weak reference made it a no-op). That
        // late invocation is safe: the timer is retained by the response-handling
        // closures until the request completes, and a post-completion cancel is
        // dropped by the completion guards (`hasCompleted` et al.) downstream.
        let hasTimedOut = Locked(false)
        let onTimeout = Locked<(@Sendable () -> Void)?>(nil)
        self.timeout = timeout
        self.hasTimedOut = hasTimedOut
        self.onTimeout = onTimeout
        self.workItem = DispatchWorkItem {
            hasTimedOut.value = true
            onTimeout.value?()
        }
    }

    deinit {
        self.cancel()
    }

    func start(onTimeout: @escaping @Sendable () -> Void) {
        let milliseconds = Int(self.timeout * 1_000)
        self.onTimeout.value = onTimeout
        self.queue.asyncAfter(
            deadline: .now() + .milliseconds(milliseconds), execute: self.workItem
        )
    }

    func cancel() {
        self.workItem.cancel()
    }
}
