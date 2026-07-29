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

/// Fires a callback if a configured deadline elapses before the timer is canceled.
///
/// Cancelation is sticky: once `cancel()` has been called the timer can never fire, even if
/// `start(onTimeout:)` runs afterwards. `ProtocolClient` depends on this - draining pending
/// request callbacks can synchronously reach `cancel()` before `start()`.
final class TimeoutTimer: Sendable {
    private enum State {
        case ready
        case started(Task<Void, Never>)
        case canceled
    }

    private let hasTimedOut = Locked(false)
    private let state = Locked<State>(.ready)
    private let timeout: TimeInterval

    var timedOut: Bool {
        return self.hasTimedOut.value
    }

    init?(config: ProtocolClientConfig) {
        guard let timeout = config.timeout else {
            return nil
        }

        self.timeout = timeout
    }

    deinit {
        self.cancel()
    }

    /// Start the timer. Has no effect if `cancel()` has already been called.
    func start(onTimeout: @escaping @Sendable () -> Void) {
        // Clamped: `timeout` is caller-supplied, and `UInt64(negativeDouble)` traps.
        let nanoseconds = UInt64(max(0, self.timeout * 1_000_000_000))
        // Capturing the box rather than `self` lets `deinit` disarm an orphaned timer.
        let hasTimedOut = self.hasTimedOut
        let task = Task {
            do {
                try await Task.sleep(nanoseconds: nanoseconds)
            } catch {
                return
            }

            hasTimedOut.value = true
            // Must stay outside any lock: this re-enters `cancel()`/`deinit` via cancelation,
            // which is the deadlock fixed in #389.
            onTimeout()
        }
        let wasCanceled = self.state.perform { state -> Bool in
            switch state {
            case .canceled:
                return true
            case .ready, .started:
                state = .started(task)
                return false
            }
        }
        if wasCanceled {
            task.cancel()
        }
    }

    func cancel() {
        let task = self.state.perform { state -> Task<Void, Never>? in
            switch state {
            case .started(let task):
                state = .canceled
                return task
            case .ready, .canceled:
                state = .canceled
                return nil
            }
        }
        task?.cancel()
    }
}
