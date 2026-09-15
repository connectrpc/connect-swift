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

struct ConnectUnaryChannelHandlerTests {
    @Test
    func sendsContentLengthByDefault() throws {
        let headers = try Self.outboundHeaders(contentLength: .sent)

        #expect(headers.first(name: "Content-Length") == "5")
    }

    @Test
    func omitsContentLengthWhenRequested() throws {
        let headers = try Self.outboundHeaders(contentLength: .omitted)

        #expect(!headers.contains(name: "Content-Length"))
    }

    @Test(arguments: [NIOHTTPClient.ContentLength.sent, .omitted])
    func alwaysSendsHostAndCallerHeaders(contentLength: NIOHTTPClient.ContentLength) throws {
        let headers = try Self.outboundHeaders(contentLength: contentLength)

        #expect(headers.first(name: "Host") == "connectrpc.com")
        #expect(headers.first(name: "x-custom-header") == "value")
    }

    private static func outboundHeaders(
        contentLength: NIOHTTPClient.ContentLength
    ) throws -> NIOHTTP1.HTTPHeaders {
        let channel = EmbeddedChannel()
        let request = Connect.HTTPRequest<Data?>(
            url: URL(string: "https://connectrpc.com/connectrpc.Service/Method")!,
            headers: ["x-custom-header": ["value"]],
            message: Data([0, 0, 0, 0, 0]),
            method: .post,
            trailers: nil,
            idempotencyLevel: .unknown
        )
        let handler = ConnectUnaryChannelHandler(
            request: request,
            eventLoop: channel.eventLoop,
            contentLength: contentLength,
            onMetrics: { _ in },
            onResponse: { _ in }
        )
        try channel.pipeline.syncOperations.addHandler(handler)
        channel.pipeline.fireChannelActive()

        let outbound = try channel.readOutbound(as: NIOHTTP1.HTTPClientRequestPart.self)
        guard case .head(let head) = try #require(outbound) else {
            Issue.record("Expected a request head to be written")
            return NIOHTTP1.HTTPHeaders()
        }
        return head.headers
    }
}
