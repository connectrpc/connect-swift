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

import NIOConcurrencyHelpers
import NIOCore
import NIOPosix

/// Owns the lifetime of an `EventLoopGroup` and gates the scheduling of work onto its event loops.
///
/// Callers which can outlive the client that created them - such as a cancelation closure invoked
/// from an unstructured task - hold this type **weakly**. A call arriving while the client is alive
/// keeps the group running across the hop onto the event loop, and a call arriving after the client
/// is gone finds nothing and is dropped rather than being scheduled onto a loop which has already
/// shut down.
///
/// Weak references are load-bearing here, and strong ones are not an option: channel handlers are
/// not reliably released today, so retaining the group from a handler would pin one event loop OS
/// thread per request forever. Both leaks are unconditional:
/// - `ProtocolClient`'s `onResult` closure captures the bidirectional stream strongly, that closure
///   is stored in the `ResponseCallbacks` held by `ConnectStreamChannelHandler`, and the stream's
///   `RequestCallbacks` retain the handler in turn. Every async stream leaks its handler.
/// - When a timeout is configured, `TimeoutTimer.cancel()` never clears `onTimeout`, which retains
///   the closure holding the request's cancelable, and through it the handler.
final class EventLoopGroupOwner: @unchecked Sendable {
    private let group: NIOCore.EventLoopGroup
    private let isGroupOwned: Bool
    private let lock = NIOConcurrencyHelpers.NIOLock()
    /// Guarded by `lock`.
    private var isShutDown = false

    /// The underlying group, for use when creating bootstraps and channels.
    var eventLoopGroup: NIOCore.EventLoopGroup {
        return self.group
    }

    /// Creates an owner of a new single-threaded group whose lifetime it fully manages.
    convenience init() {
        self.init(
            group: NIOPosix.MultiThreadedEventLoopGroup(numberOfThreads: 1), isGroupOwned: true
        )
    }

    /// - parameter group: The group onto whose loops this owner schedules work.
    /// - parameter isGroupOwned: Whether this owner is responsible for shutting the group down.
    ///                           An injected group belongs to its creator and is never shut down
    ///                           here, so that it may safely be shared between clients.
    init(group: NIOCore.EventLoopGroup, isGroupOwned: Bool) {
        self.group = group
        self.isGroupOwned = isGroupOwned
    }

    /// - returns: The next event loop which should be used for a request or stream.
    func next() -> NIOCore.EventLoop {
        return self.group.next()
    }

    /// Runs an action on the given event loop unless the group has already been shut down.
    ///
    /// - parameter eventLoop: The loop on which to run the action. Must belong to this group.
    /// - parameter action: The action to run.
    ///
    /// - returns: True if the action ran or was enqueued, false if it was dropped.
    @discardableResult
    func execute(
        on eventLoop: NIOCore.EventLoop, _ action: @escaping @Sendable () -> Void
    ) -> Bool {
        // The on-loop fast path stays outside the lock so that an action which re-enters this
        // function from the loop's own thread cannot deadlock against it.
        if eventLoop.inEventLoop {
            action()
            return true
        }

        // The lock is deliberately held *across* the enqueue. NIO accepts tasks while a loop is
        // both `.open` and `.closing`, so any enqueue which happens-before `shutdownGracefully()`
        // is guaranteed to land and drain. Checking the flag before taking the lock, or replacing
        // it with an atomic, would leave a window in which the group shuts down between the check
        // and the enqueue - which is precisely the bug this type exists to close.
        //
        // Holding the lock across `eventLoop.execute` is safe: for an off-loop caller NIO only
        // appends the task under its own internal lock and wakes the selector, so no foreign code
        // runs underneath this lock. Lock ordering: `NIOHTTPClient`'s lock may be taken before this
        // one, never the reverse.
        return self.lock.withLock { () -> Bool in
            if self.isShutDown {
                return false
            }

            // `execute` rather than `submit(_:).cascade(to: nil)`: `submit` allocates a promise
            // which is never fulfilled when the enqueue fails, and `EventLoopFuture.deinit` traps
            // on a leaked promise in debug builds. `execute` performs the same enqueue with no
            // promise attached.
            eventLoop.execute { withExtendedLifetime(self) { action() } }
            return true
        }
    }

    /// Stops scheduling new work and, if this owner created the group, shuts the group down.
    /// Idempotent, so `deinit` may safely call this after an explicit call.
    func shutDown() {
        let shouldShutDownGroup = self.lock.withLock { () -> Bool in
            if self.isShutDown {
                return false
            }

            self.isShutDown = true
            return self.isGroupOwned
        }

        if shouldShutDownGroup {
            // Shutting down must stay asynchronous. An event loop callback can release the last
            // reference to this owner, running `deinit` on one of the group's own threads, and
            // `syncShutdownGracefully()` traps there because a loop cannot wait for itself to
            // stop. The `withExtendedLifetime(self)` above makes that release land on an event loop
            // thread more often than it otherwise would, so this is more load-bearing than it looks
            // - never switch it back to the synchronous form.
            self.group.shutdownGracefully { _ in }
        }
    }

    deinit {
        self.shutDown()
    }
}
