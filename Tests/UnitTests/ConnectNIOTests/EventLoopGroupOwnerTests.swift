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
import NIOCore
import NIOPosix
import Testing

/// Uses a real `MultiThreadedEventLoopGroup` rather than `EmbeddedEventLoop`, whose `inEventLoop`
/// is unconditionally `true` - the off-loop path tested here would never be taken.
struct EventLoopGroupOwnerTests {
    /// Touched only on the event loop thread which creates it.
    private final class InlineAction: @unchecked Sendable {
        var didRun = false
    }

    /// An action scheduled from off the loop runs while the group is alive.
    @available(macOS 13, iOS 16, watchOS 9, tvOS 16, *)
    @Test(.timeLimit(.minutes(1)))
    func executesActionWhileGroupIsRunning() async {
        let owner = EventLoopGroupOwner()
        defer { owner.shutDown() }

        await confirmation("the action runs") { confirm in
            await withCheckedContinuation { continuation in
                let wasScheduled = owner.next().run {
                    confirm()
                    continuation.resume()
                }
                #expect(wasScheduled)
            }
        }
    }

    /// The invariant this type encodes: once shut down, actions are dropped rather than scheduled
    /// onto a loop which can no longer run them.
    @Test
    func dropsActionAfterShutDown() async {
        let owner = EventLoopGroupOwner()
        let handle = owner.next()
        owner.shutDown()

        // The gate is synchronous, so a dropped action can be asserted without waiting.
        await confirmation("the action never runs", expectedCount: 0) { confirm in
            let wasScheduled = handle.run { confirm() }
            #expect(!wasScheduled)
        }
    }

    /// Actions submitted from the loop's own thread run inline, so an action re-entering the owner
    /// cannot deadlock against its lock.
    @available(macOS 13, iOS 16, watchOS 9, tvOS 16, *)
    @Test(.timeLimit(.minutes(1)))
    func runsActionInlineWhenAlreadyOnEventLoop() async {
        let owner = EventLoopGroupOwner()
        defer { owner.shutDown() }

        let handle = owner.next()
        let ranInline: Bool = await withCheckedContinuation { continuation in
            handle.loop.execute {
                let action = InlineAction()
                handle.run { action.didRun = true }
                // Read back on the same thread: true only if the action ran without a hop.
                continuation.resume(returning: action.didRun)
            }
        }

        #expect(ranInline)
    }

    /// An injected group belongs to its creator and may be shared, so it is never shut down here.
    @available(macOS 13, iOS 16, watchOS 9, tvOS 16, *)
    @Test(.timeLimit(.minutes(1)))
    func doesNotShutDownInjectedGroup() async {
        let group = NIOPosix.MultiThreadedEventLoopGroup(numberOfThreads: 1)
        let owner = EventLoopGroupOwner(group: group, isGroupOwned: false)
        let eventLoop = owner.next().loop
        owner.shutDown()
        #expect(!owner.hasInitiatedGroupShutDown)

        await confirmation("the injected group still schedules") { confirm in
            await withCheckedContinuation { continuation in
                eventLoop.execute {
                    confirm()
                    continuation.resume()
                }
            }
        }

        try? await group.shutdownGracefully()
    }

    /// NIO schedules some work onto the loop itself, bypassing `execute(on:_:)` - a connect hops
    /// back from its DNS offload queue. The group must stay up while such work is outstanding.
    ///
    /// Asserted on the owner rather than by scheduling onto the loop: `shutdownGracefully` is
    /// asynchronous and a closing loop still accepts tasks, so a liveness probe would race.
    @Test
    func deferShutDownWhileWorkIsOutstanding() {
        let owner = EventLoopGroupOwner()
        #expect(owner.beginWork())

        owner.shutDown()
        #expect(!owner.hasInitiatedGroupShutDown, "Shutdown must wait for outstanding work.")

        owner.endWork()
        #expect(owner.hasInitiatedGroupShutDown, "The last endWork() must shut the group down.")
    }

    /// Work cannot be registered once the group is shut down: there is nothing left to keep alive.
    @Test
    func refusesWorkAfterShutDown() {
        let owner = EventLoopGroupOwner()
        owner.shutDown()
        #expect(!owner.beginWork())
    }

    /// Shutdown must stay asynchronous: `syncShutdownGracefully()` traps on a thread belonging to
    /// the group being shut down, which is where the owner's last reference is often released.
    @available(macOS 13, iOS 16, watchOS 9, tvOS 16, *)
    @Test(.timeLimit(.minutes(1)))
    func shutDownFromInsideEventLoopDoesNotTrap() async {
        let owner = EventLoopGroupOwner()
        await confirmation("shutDown() returns from the event loop thread") { confirm in
            await withCheckedContinuation { continuation in
                owner.next().loop.execute {
                    owner.shutDown()
                    confirm()
                    continuation.resume()
                }
            }
        }
    }
}
