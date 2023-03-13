// Copyright 2022-2023 Buf Technologies, Inc.
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
import Foundation
import NIOCore
import NIOHTTP1

/// NIO-based channel handler for streams made through the Connect library.
final class ConnectStreamChannelHandler: NIOCore.ChannelInboundHandler {
    private let request: Connect.HTTPRequest
    private let responseCallbacks: Connect.ResponseCallbacks

    private var context: NIOCore.ChannelHandlerContext?
    private var isClosed = false
    private var pendingData = Data()

    init(
        request: Connect.HTTPRequest,
        responseCallbacks: Connect.ResponseCallbacks
    ) {
        self.request = request
        self.responseCallbacks = responseCallbacks
    }

    /// Send outbound data over the stream.
    ///
    /// - parameter data: The data to send.
    func sendData(_ data: Data) {
        if self.isClosed {
            return
        }

        if let context = self.context {
            self.sendPendingData(data, using: context)
        } else {
            self.pendingData.append(contentsOf: data)
        }
    }

    /// Close the stream.
    ///
    /// - parameter trailers: Optional trailers to send when closing the stream.
    func close(trailers: Connect.Trailers?) {
        if self.isClosed {
            return
        }

        if let trailers = trailers {
            var nioTrailers = NIOHTTP1.HTTPHeaders()
            nioTrailers.addConnectHeaders(trailers)
            self.context?.writeAndFlush(self.wrapOutboundOut(.end(nioTrailers))).cascade(to: nil)
        } else {
            self.context?.writeAndFlush(self.wrapOutboundOut(.end(nil))).cascade(to: nil)
        }
    }

    /// Cancel the stream, if currently active.
    func cancel() {
        if self.isClosed {
            return
        }

        self.isClosed = true
        self.context?.close(promise: nil)
        self.responseCallbacks.receiveClose(.canceled, [:], nil)
    }

    private func sendPendingData(_ data: Data, using context: NIOCore.ChannelHandlerContext) {
        context.writeAndFlush(self.wrapOutboundOut(.body(.byteBuffer(.init(bytes: data)))))
            .cascade(to: nil)
    }

    // MARK: - ChannelInboundHandler

    typealias OutboundOut = NIOHTTP1.HTTPClientRequestPart
    typealias InboundIn = NIOHTTP1.HTTPClientResponsePart

    func channelActive(context: NIOCore.ChannelHandlerContext) {
        self.context = context
        if self.isClosed {
            return
        }

        var nioHeaders = NIOHTTP1.HTTPHeaders()
        nioHeaders.add(name: "Content-Type", value: self.request.contentType)
        nioHeaders.add(name: "Host", value: self.request.url.host!)
        nioHeaders.addConnectHeaders(self.request.headers)

        let nioRequestHead = HTTPRequestHead(
            version: .http1_1,
            method: .POST,
            uri: self.request.url.path,
            headers: nioHeaders
        )
        if self.pendingData.isEmpty {
            context.writeAndFlush(self.wrapOutboundOut(.head(nioRequestHead))).cascade(to: nil)
        } else {
            context.write(self.wrapOutboundOut(.head(nioRequestHead))).cascade(to: nil)
            self.sendPendingData(self.pendingData, using: context)
            self.pendingData = Data()
        }
        context.fireChannelActive()
    }

    func channelRead(context: NIOCore.ChannelHandlerContext, data: NIOCore.NIOAny) {
        if self.isClosed {
            return
        }

        let clientResponse = self.unwrapInboundIn(data)
        switch clientResponse {
        case .head(let head):
            self.responseCallbacks.receiveResponseHeaders(.fromNIOHeaders(head.headers))
            context.fireChannelRead(data)
        case .body(let byteBuffer):
            if let data = byteBuffer.data() {
                self.responseCallbacks.receiveResponseData(data)
            }
            context.fireChannelRead(data)
        case .end(let trailers):
            self.responseCallbacks.receiveClose(
                .ok,
                trailers.map { .fromNIOHeaders($0) } ?? [:],
                nil
            )
            context.close(promise: nil)
            self.isClosed = true
        }
    }

    func errorCaught(context: NIOCore.ChannelHandlerContext, error: Swift.Error) {
        if self.isClosed {
            return
        }

        self.responseCallbacks.receiveClose(
            .fromHTTPStatus((error as NSError).code),
            [:],
            error
        )
        context.close(promise: nil)
        self.isClosed = true
    }
}