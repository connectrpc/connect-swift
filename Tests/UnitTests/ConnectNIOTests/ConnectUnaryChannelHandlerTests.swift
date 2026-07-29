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

import Connect
@testable import ConnectNIO
import Foundation
import NIOPosix
import Testing

/// Exercises the handler directly: `swift-nio-http2` ships no multiplexer test utilities, and
/// `EmbeddedChannel` always reports `inEventLoop == true`, so it never takes the off-loop path.
struct ConnectUnaryChannelHandlerTests {
    /// A cancelation arriving after the client is gone must be dropped. A regression takes the
    /// test process down: `submit(_:)`'s unfulfilled promise trips a debug-only trap in
    /// `EventLoopFuture.deinit`.
    @Test
    func cancelAfterGroupShutdownDoesNotTrap() async {
        // The group is owned by the test rather than by the owner so that its teardown can be
        // awaited here, making the loop provably dead before the late cancelation arrives.
        let group = NIOPosix.MultiThreadedEventLoopGroup(numberOfThreads: 1)
        let owner = EventLoopGroupOwner(group: group, isGroupOwned: false)
        let eventLoop = owner.next()
        owner.shutDown()
        try? await group.shutdownGracefully()

        await confirmation("onResponse", expectedCount: 0) { confirm in
            let handler = ConnectUnaryChannelHandler(
                request: Self.request(),
                eventLoop: eventLoop,
                onMetrics: { _ in },
                onResponse: { _ in confirm() }
            )
            handler.cancel()
        }
    }

    /// Anti-regression: a gate too aggressive would report wrong codes for conformance cases
    /// which cancel a request in flight.
    @Test
    func cancelDeliversCanceledResponseWhileGroupIsRunning() async {
        let owner = EventLoopGroupOwner()
        defer { owner.shutDown() }

        let response: Connect.HTTPResponse = await withCheckedContinuation { continuation in
            let handler = ConnectUnaryChannelHandler(
                request: Self.request(),
                eventLoop: owner.next(),
                onMetrics: { _ in },
                onResponse: { continuation.resume(returning: $0) }
            )
            handler.cancel()
        }

        #expect(response.code == .canceled)
        #expect((response.error as? ConnectError)?.code == .canceled)
    }

    private static func request() -> Connect.HTTPRequest<Data?> {
        return HTTPRequest(
            url: URL(string: "https://connectrpc.com/test")!,
            headers: [:],
            message: nil,
            method: .post,
            trailers: nil,
            idempotencyLevel: .unknown
        )
    }
}
