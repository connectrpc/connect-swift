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
import Foundation
import NIOCore
import NIOFoundationCompat
import NIOHTTP1

/// NIO-based channel handler for unary requests made through the Connect library.
///
/// Loop-confined mutable state is held in `NIOLoopBoundBox`, which runtime-asserts
/// that every read/write occurs on `self.eventLoop`. External entry points hop via
/// `runOnEventLoop`; NIO invokes `ChannelInboundHandler` callbacks on the event loop.
final class ConnectUnaryChannelHandler: NIOCore.ChannelInboundHandler, Sendable {
    private struct State {
        var context: NIOCore.ChannelHandlerContext?
        var isClosed = false
        var hasResponded = false
        var receivedHead: NIOHTTP1.HTTPResponseHead?
        var receivedData: Foundation.Data?
        var receivedEnd: NIOHTTP1.HTTPHeaders?
    }

    private let eventLoop: NIOCore.EventLoop
    private let request: Connect.HTTPRequest<Data?>
    private let onMetrics: @Sendable (Connect.HTTPMetrics) -> Void
    private let onResponse: @Sendable (Connect.HTTPResponse) -> Void
    private let state: NIOLoopBoundBox<State>

    init(
        request: Connect.HTTPRequest<Data?>,
        eventLoop: NIOCore.EventLoop,
        onMetrics: @escaping @Sendable (Connect.HTTPMetrics) -> Void,
        onResponse: @escaping @Sendable (Connect.HTTPResponse) -> Void
    ) {
        self.request = request
        self.eventLoop = eventLoop
        self.onMetrics = onMetrics
        self.onResponse = onResponse
        self.state = .makeBoxSendingValue(State(), eventLoop: eventLoop)
    }

    /// Cancel the in-flight request, if currently active.
    func cancel() {
        self.runOnEventLoop {
            if self.state.value.isClosed {
                return
            }

            self.closeConnection()
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
            code: self.state.value.receivedHead.map { .fromNIOStatus($0.status) } ?? .unknown,
            headers: self.state.value.receivedHead.map { .fromNIOHeaders($0.headers) } ?? [:],
            message: self.state.value.receivedData,
            trailers: self.state.value.receivedEnd.map { .fromNIOHeaders($0) } ?? [:],
            error: error,
            tracingInfo: self.state.value.receivedHead.map {
                .init(httpStatus: Int($0.status.code))
            }
        )
    }

    private func closeConnection() {
        if self.state.value.isClosed {
            return
        }

        self.state.value.hasResponded = true
        self.state.value.isClosed = true
        self.state.value.context?.close(promise: nil)
    }

    // MARK: - ChannelInboundHandler

    typealias OutboundOut = NIOHTTP1.HTTPClientRequestPart
    typealias InboundIn = NIOHTTP1.HTTPClientResponsePart

    func channelActive(context: NIOCore.ChannelHandlerContext) {
        if self.state.value.isClosed {
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
        if self.state.value.isClosed {
            return
        }

        let response = self.unwrapInboundIn(data)
        switch response {
        case .head(let head):
            self.state.value.receivedHead = head
            context.fireChannelRead(data)
        case .body(let byteBuffer):
            if self.state.value.receivedData != nil {
                self.state.value.receivedData?.append(Data(buffer: byteBuffer))
            } else {
                self.state.value.receivedData = Data(buffer: byteBuffer)
            }
            context.fireChannelRead(data)
        case .end(let trailers):
            self.state.value.receivedEnd = trailers
            self.onResponse(self.createResponse(error: nil))
            self.onMetrics(.init(taskMetrics: nil))
            self.closeConnection()
        }
    }

    func handlerAdded(context: NIOCore.ChannelHandlerContext) {
        self.state.value.context = context
    }

    func handlerRemoved(context: NIOCore.ChannelHandlerContext) {
        self.state.value.context = nil
    }

    func channelInactive(context: ChannelHandlerContext) {
        let shouldNotify = !self.state.value.hasResponded
        self.closeConnection()
        if shouldNotify {
            self.onResponse(.init(
                code: .unavailable,
                headers: [:],
                message: nil,
                trailers: [:],
                error: ConnectError(
                    code: .unavailable,
                    message: "Channel became inactive",
                    exception: nil,
                    details: [],
                    metadata: [:]
                ),
                tracingInfo: nil
            ))
        }
        context.fireChannelInactive()
    }

    func errorCaught(context: NIOCore.ChannelHandlerContext, error: Swift.Error) {
        if self.state.value.isClosed {
            return
        }

        self.onResponse(self.createResponse(error: error))
        self.closeConnection()
    }

    func userInboundEventTriggered(context: ChannelHandlerContext, event: Any) {
        guard event is NIOCore.IdleStateHandler.IdleStateEvent else {
            return context.fireUserInboundEventTriggered(event)
        }

        self.closeConnection()
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
