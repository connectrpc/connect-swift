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
struct ConnectStreamChannelHandlerTests {
    private typealias StreamClose = (code: Code, error: Swift.Error?)

    /// A cancelation arriving after the client is gone must be dropped. A regression takes the
    /// test process down: `submit(_:)`'s unfulfilled promise trips a debug-only trap in
    /// `EventLoopFuture.deinit`.
    @Test
    func cancelAfterGroupShutdownDoesNotTrap() async {
        await Self.withHandlerOnShutDownGroup { handler in
            handler.cancel()
        }
    }

    /// Outbound data takes the same off-loop path and must likewise be dropped.
    @Test
    func sendDataAfterShutdownIsDropped() async {
        await Self.withHandlerOnShutDownGroup { handler in
            handler.sendData(Data([0x0, 0x1, 0x2]))
        }
    }

    /// Half-closing takes the same off-loop path and must likewise be dropped.
    @Test
    func closeAfterShutdownIsDropped() async {
        await Self.withHandlerOnShutDownGroup { handler in
            handler.close()
        }
    }

    /// Anti-regression: a gate too aggressive would report wrong codes for conformance cases
    /// which cancel a stream in flight.
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
                eventLoop: owner.next()
            )
            handler.cancel()
        }

        #expect(close.code == .canceled)
        #expect((close.error as? ConnectError)?.code == .canceled)
    }

    /// Runs `action` off-loop against a handler whose group is shut down, asserting no callback
    /// fires.
    private static func withHandlerOnShutDownGroup(
        _ action: (ConnectStreamChannelHandler) -> Void
    ) async {
        // Owned by the test so its teardown can be awaited, making the loop provably dead.
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
                eventLoop: eventLoop
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
