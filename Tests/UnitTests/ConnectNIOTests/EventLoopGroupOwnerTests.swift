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

@testable import ConnectNIO
import Dispatch
import NIOCore
import NIOPosix
import Testing

/// These tests deliberately use a real `MultiThreadedEventLoopGroup` rather than
/// `EmbeddedEventLoop`, whose `inEventLoop` is unconditionally `true` - the off-loop path being
/// tested here would never be taken.
struct EventLoopGroupOwnerTests {
    /// An action scheduled from off the event loop runs while the group is still alive.
    @Test
    func executesActionWhileGroupIsRunning() {
        let owner = EventLoopGroupOwner()
        defer { owner.shutDown() }

        let didRun = DispatchSemaphore(value: 0)
        let wasScheduled = owner.execute(on: owner.next()) { didRun.signal() }
        #expect(wasScheduled)
        #expect(didRun.wait(timeout: .now() + .seconds(5)) == .success)
    }

    /// The invariant this type exists to encode: once the group has been shut down, later actions
    /// are dropped rather than scheduled onto an event loop which can no longer run them.
    @Test
    func dropsActionAfterShutDown() {
        let owner = EventLoopGroupOwner()
        let eventLoop = owner.next()
        owner.shutDown()

        let didRun = DispatchSemaphore(value: 0)
        let wasScheduled = owner.execute(on: eventLoop) { didRun.signal() }
        #expect(!wasScheduled)
        #expect(didRun.wait(timeout: .now() + .milliseconds(100)) == .timedOut)
    }

    /// Actions submitted from the event loop's own thread run inline rather than being enqueued,
    /// so that an action which re-enters the owner cannot deadlock against its lock.
    @Test
    func runsActionInlineWhenAlreadyOnEventLoop() {
        let owner = EventLoopGroupOwner()
        defer { owner.shutDown() }

        let eventLoop = owner.next()
        let ranInline = DispatchSemaphore(value: 0)
        let finished = DispatchSemaphore(value: 0)
        eventLoop.execute {
            let didRun = DispatchSemaphore(value: 0)
            let wasScheduled = owner.execute(on: eventLoop) { didRun.signal() }
            // A zero timeout only succeeds if the action has already run, i.e. ran inline.
            if wasScheduled, didRun.wait(timeout: .now()) == .success {
                ranInline.signal()
            }
            finished.signal()
        }

        #expect(finished.wait(timeout: .now() + .seconds(5)) == .success)
        #expect(ranInline.wait(timeout: .now()) == .success, "The action should run inline.")
    }

    /// An injected group belongs to its creator and may be shared between clients, so the owner
    /// must never shut it down.
    @Test
    func doesNotShutDownInjectedGroup() {
        let group = NIOPosix.MultiThreadedEventLoopGroup(numberOfThreads: 1)
        defer { try? group.syncShutdownGracefully() }

        let owner = EventLoopGroupOwner(group: group, isGroupOwned: false)
        let eventLoop = owner.next()
        owner.shutDown()

        let didRun = DispatchSemaphore(value: 0)
        eventLoop.execute { didRun.signal() }
        #expect(didRun.wait(timeout: .now() + .seconds(5)) == .success)
    }

    /// Shutdown must stay asynchronous: `syncShutdownGracefully()` traps when it runs on a thread
    /// belonging to the group being shut down, which is exactly what happens when the last
    /// reference to the owner is released by an event loop callback.
    @Test
    func shutDownFromInsideEventLoopDoesNotTrap() {
        let owner = EventLoopGroupOwner()
        let finished = DispatchSemaphore(value: 0)
        owner.next().execute {
            owner.shutDown()
            finished.signal()
        }
        #expect(finished.wait(timeout: .now() + .seconds(5)) == .success)
    }
}
