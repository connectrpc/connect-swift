// Copyright 2022-2024 The Connect Authors
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
import NIOFoundationCompat
import NIOHTTP1

/// NIO-based channel handler for unary requests made through the Connect library.
final class ConnectUnaryChannelHandler: NIOCore.ChannelInboundHandler, @unchecked Sendable {
    private let eventLoop: NIOCore.EventLoop
    private let request: Connect.HTTPRequest<Data?>
    private let onMetrics: (Connect.HTTPMetrics) -> Void
    private let onResponse: (Connect.HTTPResponse) -> Void

    private var context: NIOCore.ChannelHandlerContext?
    private var isClosed = false
    private var receivedHead: NIOHTTP1.HTTPResponseHead?
    private var receivedData: Foundation.Data?
    private var receivedEnd: NIOHTTP1.HTTPHeaders?

    init(
        request: Connect.HTTPRequest<Data?>,
        eventLoop: NIOCore.EventLoop,
        onMetrics: @escaping (Connect.HTTPMetrics) -> Void,
        onResponse: @escaping (Connect.HTTPResponse) -> Void
    ) {
        self.request = request
        self.eventLoop = eventLoop
        self.onMetrics = onMetrics
        self.onResponse = onResponse
    }

    /// Cancel the in-flight request, if currently active.
    func cancel() {
        self.runOnEventLoop {
            if self.isClosed {
                return
            }

            self.isClosed = true
            self.context?.close(promise: nil)
            self.onResponse(HTTPResponse(
                code: .canceled,
                headers: [:],
                message: nil,
                trailers: [:],
                error: ConnectError.canceled(),
                tracingInfo: nil
            ))
        }
    }

    private func runOnEventLoop(action: @escaping @Sendable () -> Void) {
        if self.eventLoop.inEventLoop {
            action()
        } else {
            self.eventLoop.submit(action).cascade(to: nil)
        }
    }

    private func createResponse(error: Swift.Error?) -> Connect.HTTPResponse {
        return HTTPResponse(
            code: self.receivedHead.map { .fromNIOStatus($0.status) } ?? .unknown,
            headers: self.receivedHead.map { .fromNIOHeaders($0.headers) } ?? [:],
            message: self.receivedData,
            trailers: self.receivedEnd.map { .fromNIOHeaders($0) } ?? [:],
            error: error,
            tracingInfo: self.receivedHead.map { .init(httpStatus: Int($0.status.code)) }
        )
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
        if let messageLength = self.request.message?.count {
            nioHeaders.add(name: "Content-Length", value: "\(messageLength)")
        }
        nioHeaders.add(name: "Host", value: self.request.url.host!)
        nioHeaders.addNIOHeadersFromConnect(self.request.headers)

        let nioRequestHead = HTTPRequestHead.fromConnect(self.request, nioHeaders: nioHeaders)
        context.write(self.wrapOutboundOut(.head(nioRequestHead))).cascade(to: nil)
        if let message = self.request.message {
            context.write(self.wrapOutboundOut(.body(.byteBuffer(.init(data: message)))))
                .cascade(to: nil)
        }
        if let trailers = self.request.trailers {
            var nioTrailers = NIOHTTP1.HTTPHeaders()
            nioTrailers.addNIOHeadersFromConnect(trailers)
            context.writeAndFlush(self.wrapOutboundOut(.end(nioTrailers))).cascade(to: nil)
        } else {
            context.writeAndFlush(self.wrapOutboundOut(.end(nil))).cascade(to: nil)
        }

        context.fireChannelActive()
    }

    func channelRead(context: NIOCore.ChannelHandlerContext, data: NIOCore.NIOAny) {
        if self.isClosed {
            return
        }

        let response = self.unwrapInboundIn(data)
        switch response {
        case .head(let head):
            self.receivedHead = head
            context.fireChannelRead(data)
        case .body(let byteBuffer):
            if self.receivedData != nil {
                self.receivedData?.append(Data(buffer: byteBuffer))
            } else {
                self.receivedData = Data(buffer: byteBuffer)
            }
            context.fireChannelRead(data)
        case .end(let trailers):
            self.receivedEnd = trailers
            self.onResponse(self.createResponse(error: nil))
            self.onMetrics(.init(taskMetrics: nil))
            context.close(promise: nil)
            self.isClosed = true
        }
    }

    func errorCaught(context: NIOCore.ChannelHandlerContext, error: Swift.Error) {
        if self.isClosed {
            return
        }

        self.onResponse(self.createResponse(error: error))
        context.close(promise: nil)
        self.isClosed = true
    }

    func userInboundEventTriggered(context: ChannelHandlerContext, event: Any) {
        guard event is NIOCore.IdleStateHandler.IdleStateEvent else {
            return context.fireUserInboundEventTriggered(event)
        }

        self.isClosed = true
        context.close(promise: nil)
        self.onResponse(.init(
            code: .deadlineExceeded,
            headers: [:],
            message: nil,
            trailers: [:],
            error: ConnectError.deadlineExceeded(),
            tracingInfo: nil
        ))
    }
}
