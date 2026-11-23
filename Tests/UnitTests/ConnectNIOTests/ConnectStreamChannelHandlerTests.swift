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
import NIOCore
import NIOEmbedded
import NIOHTTP1
import Testing

struct ConnectStreamChannelHandlerTests {
    enum CloseEvent: CaseIterable, CustomTestStringConvertible {
        case trailers
        case cancel
        case error
        case channelInactive
        case idleTimeout

        var testDescription: String {
            switch self {
            case .trailers: "the server trailers"
            case .cancel: "a cancel"
            case .error: "an error"
            case .channelInactive: "an inactive channel"
            case .idleTimeout: "an idle timeout"
            }
        }
    }

    /// The response callbacks keep the stream that owns the handler, and that stream keeps the
    /// handler through its request callbacks. A handler that keeps the callbacks after it reports
    /// the close therefore keeps the stream, and its interceptors, forever.
    @Test(arguments: CloseEvent.allCases)
    func releasesResponseCallbacksAfterReportingClose(_ event: CloseEvent) throws {
        let channel = EmbeddedChannel()
        let closes = CloseCounter()
        weak var callbackOwner: CallbackOwner?
        let handler = try {
            // Only the response callbacks keep this object.
            let owner = CallbackOwner()
            callbackOwner = owner
            return ConnectStreamChannelHandler(
                request: HTTPRequest(
                    url: try #require(URL(string: "https://connectrpc.com/test")), headers: [:],
                    message: nil, method: .post, trailers: nil, idempotencyLevel: .unknown
                ),
                responseCallbacks: ResponseCallbacks(
                    receiveResponseHeaders: { _ in owner.receive() },
                    receiveResponseData: { _ in owner.receive() },
                    receiveResponseMetrics: { _ in owner.receive() },
                    receiveClose: { _, _, _ in
                        owner.receive()
                        closes.increment()
                    }
                ),
                eventLoop: channel.embeddedEventLoop
            )
        }()
        try channel.pipeline.syncOperations.addHandler(handler)
        try channel.connect(to: SocketAddress(ipAddress: "127.0.0.1", port: 443)).wait()
        #expect(callbackOwner != nil)

        switch event {
        case .trailers:
            try channel.writeInbound(
                HTTPClientResponsePart.head(.init(version: .http2, status: .ok)))
            try channel.writeInbound(HTTPClientResponsePart.end(nil))
        case .cancel:
            handler.cancel()
        case .error:
            channel.pipeline.fireErrorCaught(TestError())
        case .channelInactive:
            try channel.close().wait()
        case .idleTimeout:
            channel.pipeline.fireUserInboundEventTriggered(IdleStateHandler.IdleStateEvent.read)
        }

        #expect(closes.count == 1)
        #expect(callbackOwner == nil, "The handler kept its response callbacks after the close.")
        _ = try? channel.finish()
    }
}

private struct TestError: Error {}

private final class CallbackOwner: Sendable {
    func receive() {}
}

/// Counts close reports. An `EmbeddedChannel` runs everything on the test's thread.
private final class CloseCounter: @unchecked Sendable {
    private(set) var count = 0

    func increment() {
        count += 1
    }
}
