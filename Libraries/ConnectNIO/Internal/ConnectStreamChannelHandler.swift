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

/// NIO-based channel handler for streams made through the Connect library.
///
/// Loop-confined mutable state is held in `NIOLoopBoundBox`, which runtime-asserts
/// that every read/write occurs on `self.eventLoop`. External entry points hop via
/// `runOnEventLoop`; NIO invokes `ChannelInboundHandler` callbacks on the event loop.
final class ConnectStreamChannelHandler: NIOCore.ChannelInboundHandler, Sendable {
    private struct State {
        var context: NIOCore.ChannelHandlerContext?
        var isClosed = false
        var hasResponded = false
        var pendingClose: NIOHTTP1.HTTPClientRequestPart?
        var pendingData = Foundation.Data()
        var receivedStatus: NIOHTTP1.HTTPResponseStatus?
    }

    private let eventLoop: NIOCore.EventLoop
    private let request: Connect.HTTPRequest<Data?>
    private let responseCallbacks: Connect.ResponseCallbacks
    private let state: NIOLoopBoundBox<State>

    init(
        request: Connect.HTTPRequest<Data?>,
        responseCallbacks: Connect.ResponseCallbacks,
        eventLoop: NIOCore.EventLoop
    ) {
        self.request = request
        self.responseCallbacks = responseCallbacks
        self.eventLoop = eventLoop
        self.state = .makeBoxSendingValue(State(), eventLoop: eventLoop)
    }

    /// Send outbound data over the stream.
    ///
    /// - parameter data: The data to send.
    func sendData(_ data: Data) {
        self.runOnEventLoop {
            if self.state.value.isClosed {
                return
            }

            if let context = self.state.value.context {
                context.writeAndFlush(self.wrapOutboundOut(.body(.byteBuffer(.init(data: data)))))
                    .cascade(to: nil)
            } else {
                self.state.value.pendingData.append(contentsOf: data)
            }
        }
    }

    /// Close the stream.
    func close() {
        self.runOnEventLoop {
            if self.state.value.isClosed {
                return
            }

            if let context = self.state.value.context {
                context.writeAndFlush(self.wrapOutboundOut(.end(nil))).cascade(to: nil)
            } else {
                self.state.value.pendingClose = .end(nil)
            }
        }
    }

    /// Cancel the stream, if currently active.
    func cancel() {
        self.runOnEventLoop {
            if self.state.value.isClosed {
                return
            }

            self.closeConnection()
            self.responseCallbacks.receiveClose(.canceled, [:], ConnectError.canceled())
        }
    }

    private func runOnEventLoop(action: @escaping @Sendable () -> Void) {
        if self.eventLoop.inEventLoop {
            action()
        } else {
            self.eventLoop.submit(action).cascade(to: nil)
        }
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
        nioHeaders.add(name: "Host", value: self.request.url.host!)
        nioHeaders.addNIOHeadersFromConnect(self.request.headers)

        let nioRequestHead = HTTPRequestHead.fromConnect(self.request, nioHeaders: nioHeaders)
        context.write(self.wrapOutboundOut(.head(nioRequestHead))).cascade(to: nil)

        if !self.state.value.pendingData.isEmpty {
            context.write(
                self.wrapOutboundOut(.body(.byteBuffer(.init(data: self.state.value.pendingData))))
            )
            .cascade(to: nil)
            self.state.value.pendingData = Data()
        }

        if let pendingClose = self.state.value.pendingClose {
            context.write(self.wrapOutboundOut(pendingClose)).cascade(to: nil)
            self.state.value.pendingClose = nil
        }

        context.flush()
        context.fireChannelActive()
    }

    func channelRead(context: NIOCore.ChannelHandlerContext, data: NIOCore.NIOAny) {
        if self.state.value.isClosed {
            return
        }

        let response = self.unwrapInboundIn(data)
        switch response {
        case .head(let head):
            self.state.value.receivedStatus = head.status
            self.responseCallbacks.receiveResponseHeaders(.fromNIOHeaders(head.headers))
            context.fireChannelRead(data)
        case .body(let byteBuffer):
            self.responseCallbacks.receiveResponseData(Data(buffer: byteBuffer))
            context.fireChannelRead(data)
        case .end(let trailers):
            self.responseCallbacks.receiveClose(
                self.state.value.receivedStatus.map { .fromNIOStatus($0) } ?? .ok,
                trailers.map { .fromNIOHeaders($0) } ?? [:],
                nil
            )
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
            self.responseCallbacks.receiveClose(
                .unavailable,
                [:],
                ConnectError(
                    code: .unavailable,
                    message: "Channel became inactive",
                    exception: nil,
                    details: [],
                    metadata: [:]
                )
            )
        }
        context.fireChannelInactive()
    }

    func errorCaught(context: NIOCore.ChannelHandlerContext, error: Swift.Error) {
        if self.state.value.isClosed {
            return
        }

        self.responseCallbacks.receiveClose(
            .fromHTTPStatus((error as NSError).code),
            [:],
            error
        )
        self.closeConnection()
    }

    func userInboundEventTriggered(context: ChannelHandlerContext, event: Any) {
        guard event is NIOCore.IdleStateHandler.IdleStateEvent else {
            return context.fireUserInboundEventTriggered(event)
        }

        self.closeConnection()
        self.responseCallbacks.receiveClose(.deadlineExceeded, [:], ConnectError.deadlineExceeded())
    }
}
