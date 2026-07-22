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
    private let hasTimedOut = Locked(false)
    private let onTimeout = Locked<(@Sendable () -> Void)?>(nil)
    private let queue = DispatchQueue(label: "connectrpc.Timeout")
    private let timeout: TimeInterval
    // Safety: `DispatchWorkItem` is non-Sendable; the only cross-thread operation
    // performed on it is `cancel()`, which is thread-safe.
    private let workItem = Locked<DispatchWorkItem?>(nil)

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

    func start(onTimeout: @escaping @Sendable () -> Void) {
        let milliseconds = Int(self.timeout * 1_000)
        self.onTimeout.value = onTimeout
        let item = DispatchWorkItem { [weak self] in
            self?.hasTimedOut.value = true
            self?.onTimeout.value?()
        }
        self.workItem.value = item
        self.queue.asyncAfter(
            deadline: .now() + .milliseconds(milliseconds), execute: item
        )
    }

    func cancel() {
        self.workItem.value?.cancel()
    }
}
