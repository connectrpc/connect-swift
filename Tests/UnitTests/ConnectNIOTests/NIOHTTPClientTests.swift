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
import NIOPosix
import Testing

struct NIOHTTPClientTests {
    /// Requests can outlive their client: a caller may cancel one, and NIO finishes an in-flight
    /// connect on its own, after the client is released. Both schedule onto the client's event
    /// loop, which NIO treats as a programmer error once that loop has shut down.
    ///
    /// A loop fails its scheduled tasks as it shuts down, so this throws if releasing the client
    /// stops its loop.
    @Test
    func eventLoopKeepsRunningAfterClientIsReleased() async throws {
        let eventLoop = NIOHTTPClient(host: "https://connectrpc.com").eventLoop
        try await eventLoop.scheduleTask(in: .milliseconds(100)) {}.futureResult.get()
    }

    /// Since the event loop outlives the client, nothing but the client can close a connection
    /// which finishes being established after the client is released.
    @available(macOS 13, iOS 16, watchOS 9, tvOS 16, *)
    @Test(.timeLimit(.minutes(1)))
    func closesConnectionEstablishedAfterClientIsReleased() async throws {
        let (connections, continuation) = AsyncStream.makeStream(of: NIOCore.Channel.self)
        let server = try await NIOPosix.ServerBootstrap(
            group: NIOPosix.MultiThreadedEventLoopGroup.singleton
        )
        .childChannelInitializer { channel in
            continuation.yield(channel)
            return channel.eventLoop.makeSucceededVoidFuture()
        }
        .bind(host: "127.0.0.1", port: 0)
        .get()
        defer { server.close(promise: nil) }

        let host = "http://127.0.0.1"
        let port = try #require(server.localAddress?.port)
        // Scoped so the client is released while its connection is still being established.
        do {
            let client = NIOHTTPClient(host: host, port: port)
            _ = client.unary(
                request: HTTPRequest(
                    url: try #require(URL(string: "\(host):\(port)/test")), headers: [:],
                    message: nil, method: .post, trailers: nil, idempotencyLevel: .unknown
                ),
                onMetrics: { _ in },
                onResponse: { _ in }
            )
        }

        let connection = try #require(await connections.first { _ in true })
        // Raced against a deadline so a connection left open fails the test rather than hanging
        // it. Fulfilling a promise a second time is a no-op.
        let didClose = connection.eventLoop.makePromise(of: Bool.self)
        connection.closeFuture.whenComplete { _ in didClose.succeed(true) }
        let deadline = connection.eventLoop.scheduleTask(in: .seconds(5)) {
            didClose.succeed(false)
        }
        let closed = try await didClose.futureResult.get()
        deadline.cancel()
        #expect(closed, "The server never saw the connection close.")
    }
}
