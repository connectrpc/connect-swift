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
/// `.timedOut` and `.canceled` are both terminal, so cancelation is sticky - once `cancel()` has
/// been called the timer can never fire, even if `start(onTimeout:)` runs afterwards.
/// `ProtocolClient` depends on this: the stream path's inbound and outbound pumps are separate
/// concurrent tasks, and a fast `receiveClose` can reach `cancel()` on the inbound pump before the
/// outbound pump reaches `start()` after creating the transport.
final class TimeoutTimer: Sendable {
    private enum State {
        case ready
        case started(Task<Void, Never>)
        case timedOut
        case canceled
    }

    private let state = Locked<State>(.ready)
    private let timeout: TimeInterval

    var timedOut: Bool {
        if case .timedOut = self.state.value {
            return true
        }

        return false
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
        // Avoid capturing `self` so `deinit` disarms the orphaned timer.
        let state = self.state
        let task = Task {
            do {
                try await Task.sleep(nanoseconds: nanoseconds)
            } catch {
                return
            }

            // `.ready` is reachable: this task can wake before `start()` registers it below.
            let didTimeOut = state.perform { state -> Bool in
                switch state {
                case .ready, .started:
                    state = .timedOut
                    return true
                case .timedOut, .canceled:
                    return false
                }
            }
            guard didTimeOut else {
                return
            }

            // Must stay outside the lock: this re-enters `timedOut`/`cancel()`/`deinit` via
            // cancelation, which would deadlock.
            onTimeout()
        }
        let isTerminal = self.state.perform { state -> Bool in
            switch state {
            case .timedOut, .canceled:
                return true
            case .ready, .started:
                state = .started(task)
                return false
            }
        }
        if isTerminal {
            task.cancel()
        }
    }

    func cancel() {
        let task = self.state.perform { state -> Task<Void, Never>? in
            switch state {
            case .started(let task):
                state = .canceled
                return task
            case .ready:
                state = .canceled
                return nil
            case .timedOut, .canceled:
                // Terminal. `.timedOut` must survive, because `deinit` always calls `cancel()`
                // and `ProtocolClient` reads `timedOut` while the timer is still alive.
                return nil
            }
        }
        task?.cancel()
    }
}
