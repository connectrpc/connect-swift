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

/// Owns an `EventLoopGroup`'s lifetime and gates the scheduling of work onto its loops. Callers
/// schedule through the `EventLoopHandle`s it vends rather than touching a loop directly.
final class EventLoopGroupOwner: @unchecked Sendable {
    private let group: NIOCore.EventLoopGroup
    private let isGroupOwned: Bool
    private let lock = NIOConcurrencyHelpers.NIOLock()
    /// Guarded by `lock`.
    private var isShutDown = false
    /// Guarded by `lock`. Shutdown is deferred while non-zero. See `beginWork()`.
    private var outstandingWorkCount = 0
    /// Guarded by `lock`. Whether `shutDownGroup()` has run.
    private var didShutDownGroup = false

    var eventLoopGroup: NIOCore.EventLoopGroup {
        return self.group
    }

    /// Whether the group's shutdown has actually been started. Exposed for testing, since
    /// `shutdownGracefully` is asynchronous and a closing loop still accepts work, so observing
    /// this through the loop would race.
    var hasInitiatedGroupShutDown: Bool {
        return self.lock.withLock { self.didShutDownGroup }
    }

    /// Creates an owner of a new single-threaded group whose lifetime it fully manages.
    convenience init() {
        self.init(
            group: NIOPosix.MultiThreadedEventLoopGroup(numberOfThreads: 1), isGroupOwned: true
        )
    }

    /// - parameter group: The group onto whose loops this owner schedules work.
    /// - parameter isGroupOwned: Whether to shut the group down. An injected group belongs to its
    ///                           creator and is never shut down here, so it may be shared.
    init(group: NIOCore.EventLoopGroup, isGroupOwned: Bool) {
        self.group = group
        self.isGroupOwned = isGroupOwned
    }

    /// - returns: A handle to the next event loop to use for a request or stream.
    func next() -> EventLoopHandle {
        return EventLoopHandle(loop: self.group.next(), owner: self)
    }

    /// Enqueues an action onto the given event loop unless the group has already been shut down.
    /// Callers must be off the loop; `EventLoopHandle.run(_:)` handles the inline case.
    ///
    /// - returns: True if the action was enqueued, false if it was dropped.
    @discardableResult
    func enqueue(
        on eventLoop: NIOCore.EventLoop, _ action: @escaping @Sendable () -> Void
    ) -> Bool {
        // The lock deliberately spans the enqueue. NIO accepts tasks while a loop is `.open` or
        // `.closing`, so an enqueue that happens-before `shutdownGracefully()` is guaranteed to
        // drain; checking the flag before taking the lock would reopen the race. Holding it is
        // safe because NIO only appends under its own lock and wakes the selector.
        return self.lock.withLock { () -> Bool in
            if self.isShutDown {
                return false
            }

            // `execute`, not `submit(_:)`, whose promise is never fulfilled when the enqueue fails
            // and trips `EventLoopFuture.deinit`'s leaked-promise trap in debug builds.
            eventLoop.execute { withExtendedLifetime(self) { action() } }
            return true
        }
    }

    /// Registers work whose completion NIO schedules itself, bypassing `execute(on:_:)` - namely a
    /// connect, whose DNS lookup hops back onto the loop from an offload queue. Shutdown is
    /// deferred until the matching `endWork()` so that hop cannot land on a dead loop.
    ///
    /// - returns: True if the work was registered, false if the group is already shut down.
    @discardableResult
    func beginWork() -> Bool {
        return self.lock.withLock { () -> Bool in
            if self.isShutDown {
                return false
            }

            self.outstandingWorkCount += 1
            return true
        }
    }

    /// Balances a successful `beginWork()`, running a deferred shutdown if this was the last work.
    func endWork() {
        let shouldShutDownGroup = self.lock.withLock { () -> Bool in
            guard self.outstandingWorkCount > 0 else {
                return false
            }

            self.outstandingWorkCount -= 1
            return self.isShutDown && self.isGroupOwned && self.outstandingWorkCount == 0
        }

        if shouldShutDownGroup {
            self.shutDownGroup()
        }
    }

    /// Stops scheduling new work and shuts the group down once no work is outstanding.
    /// Idempotent, so `deinit` may safely call this after an explicit call.
    func shutDown() {
        let shouldShutDownGroup = self.lock.withLock { () -> Bool in
            if self.isShutDown {
                return false
            }

            self.isShutDown = true
            return self.isGroupOwned && self.outstandingWorkCount == 0
        }

        if shouldShutDownGroup {
            self.shutDownGroup()
        }
    }

    private func shutDownGroup() {
        // Called outside `lock`, so retaking it here is safe.
        self.lock.withLock { self.didShutDownGroup = true }
        // Must stay asynchronous: this owner's last reference is often released on one of the
        // group's own threads, where `syncShutdownGracefully()` traps waiting for that loop to
        // stop. Never switch it back to the synchronous form.
        self.group.shutdownGracefully { _ in }
    }

    deinit {
        self.shutDown()
    }
}

/// A single event loop paired with the gate deciding whether work may still be scheduled onto it.
///
/// The owner is held **weakly**, so a call arriving after the client is gone finds nothing and is
/// dropped rather than landing on a shut down loop. Strong references are not an option: handlers
/// are not reliably released today (the `ProtocolClient` stream/handler cycle and
/// `TimeoutTimer.cancel()` both leak them), so they would pin an event loop thread forever.
struct EventLoopHandle: Sendable {
    let loop: NIOCore.EventLoop
    private weak var owner: EventLoopGroupOwner?

    init(loop: NIOCore.EventLoop, owner: EventLoopGroupOwner) {
        self.loop = loop
        self.owner = owner
    }

    /// Runs an action on the loop, inline if already on it and enqueued otherwise.
    ///
    /// - returns: True if the action ran or was enqueued, false if it was dropped.
    @discardableResult
    func run(_ action: @escaping @Sendable () -> Void) -> Bool {
        // Inline, and outside the owner's lock, so an action re-entering from the loop's own
        // thread cannot deadlock. Being on that thread also proves the loop is still running, so
        // this holds even once the owner is gone.
        if self.loop.inEventLoop {
            action()
            return true
        }

        return self.owner?.enqueue(on: self.loop, action) ?? false
    }
}
