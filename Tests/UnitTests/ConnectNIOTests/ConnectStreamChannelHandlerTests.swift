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

/// The handler is exercised directly rather than through a channel: `swift-nio-http2` ships no
/// test utilities for the multiplexer, and `EmbeddedChannel` cannot reproduce the off-loop
/// scheduling path because its event loop always reports `inEventLoop == true`.
struct ConnectStreamChannelHandlerTests {
    private typealias StreamClose = (code: Code, error: Swift.Error?)

    /// A cancelation which arrives after the client - and therefore its event loop group - is gone
    /// must be dropped. Scheduling onto a shut down loop prints a NIO error which is slated to
    /// become a forced crash, and the unfulfilled promise left behind by `submit(_:)` trips the
    /// debug-only leaked promise trap in `EventLoopFuture.deinit`, so a regression here takes the
    /// test process down rather than surfacing in conformance runs.
    @Test
    func cancelAfterGroupShutdownDoesNotTrap() async {
        await Self.withHandlerOnShutDownGroup { handler in
            handler.cancel()
        }
    }

    /// Outbound data sent after teardown takes the same off-loop path as cancelation and must
    /// likewise be dropped rather than enqueued.
    @Test
    func sendDataAfterShutdownIsDropped() async {
        await Self.withHandlerOnShutDownGroup { handler in
            handler.sendData(Data([0x0, 0x1, 0x2]))
        }
    }

    /// Half-closing after teardown takes the same off-loop path as cancelation and must likewise
    /// be dropped rather than enqueued.
    @Test
    func closeAfterShutdownIsDropped() async {
        await Self.withHandlerOnShutDownGroup { handler in
            handler.close()
        }
    }

    /// Anti-regression for the gate above: a cancelation on a live group must still deliver
    /// `.canceled`. A gate which is too aggressive would silently report wrong codes for the
    /// conformance cases which cancel a stream in flight.
    @Test
    func cancelDeliversCanceledResponseWhileGroupIsRunning() async {
        let owner = EventLoopGroupOwner()
        defer { owner.shutDown() }

        let close: StreamClose = await withCheckedContinuation { continuation in
            let handler = ConnectStreamChannelHandler(
                request: Self.request(),
                responseCallbacks: Self.responseCallbacks(receiveClose: { code, _, error in
                    continuation.resume(returning: (code, error))
                }),
                eventLoop: owner.next(),
                loopGroupOwner: owner
            )
            handler.cancel()
        }

        #expect(close.code == .canceled)
        #expect((close.error as? ConnectError)?.code == .canceled)
    }

    /// Builds a handler over a group which is provably shut down, runs `action` against it from
    /// off the event loop, and asserts that no response callback fires as a result.
    private static func withHandlerOnShutDownGroup(
        _ action: (ConnectStreamChannelHandler) -> Void
    ) async {
        // The group is owned by the test rather than by the owner so that its teardown can be
        // awaited here, making the loop provably dead before the late call arrives.
        let group = NIOPosix.MultiThreadedEventLoopGroup(numberOfThreads: 1)
        let owner = EventLoopGroupOwner(group: group, isGroupOwned: false)
        let eventLoop = owner.next()
        owner.shutDown()
        try? await group.shutdownGracefully()

        await confirmation("response callback", expectedCount: 0) { confirm in
            let handler = ConnectStreamChannelHandler(
                request: Self.request(),
                responseCallbacks: ResponseCallbacks(
                    receiveResponseHeaders: { _ in confirm() },
                    receiveResponseData: { _ in confirm() },
                    receiveResponseMetrics: { _ in confirm() },
                    receiveClose: { _, _, _ in confirm() }
                ),
                eventLoop: eventLoop,
                loopGroupOwner: owner
            )
            action(handler)
        }
    }

    private static func responseCallbacks(
        receiveClose: @escaping @Sendable (Code, Trailers, Swift.Error?) -> Void
    ) -> Connect.ResponseCallbacks {
        return ResponseCallbacks(
            receiveResponseHeaders: { _ in },
            receiveResponseData: { _ in },
            receiveResponseMetrics: { _ in },
            receiveClose: receiveClose
        )
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
