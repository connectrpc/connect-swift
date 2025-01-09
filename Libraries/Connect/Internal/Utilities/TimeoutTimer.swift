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

final class TimeoutTimer: @unchecked Sendable {
    private var hasTimedOut = false
    private var onTimeout: (() -> Void)?
    private let queue = DispatchQueue(label: "connectrpc.Timeout")
    private let timeout: TimeInterval
    private var workItem: DispatchWorkItem! // Force-unwrapped to allow capturing self in init

    var timedOut: Bool {
        return self.queue.sync { self.hasTimedOut }
    }

    init?(config: ProtocolClientConfig) {
        guard let timeout = config.timeout else {
            return nil
        }

        self.timeout = timeout
        self.workItem = DispatchWorkItem { [weak self] in
            self?.hasTimedOut = true
            self?.onTimeout?()
        }
    }

    deinit {
        self.cancel()
    }

    func start(onTimeout: @escaping () -> Void) {
        let milliseconds = Int(self.timeout * 1_000)
        self.queue.sync { self.onTimeout = onTimeout }
        self.queue.asyncAfter(
            deadline: .now() + .milliseconds(milliseconds), execute: self.workItem
        )
    }

    func cancel() {
        self.queue.sync {
            self.workItem.cancel()
        }
    }
}
