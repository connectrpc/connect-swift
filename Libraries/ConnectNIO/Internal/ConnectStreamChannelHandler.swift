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

/// NIO-based channel handler for streams made through the Connect library.
final class ConnectStreamChannelHandler: NIOCore.ChannelInboundHandler, @unchecked Sendable {
    private let eventLoop: NIOCore.EventLoop
    private let request: Connect.HTTPRequest<Data?>
    private let responseCallbacks: Connect.ResponseCallbacks

    private var context: NIOCore.ChannelHandlerContext?
    private var isClosed = false
    private var pendingClose: NIOHTTP1.HTTPClientRequestPart?
    private var pendingData = Foundation.Data()
    private var receivedStatus: NIOHTTP1.HTTPResponseStatus?

    init(
        request: Connect.HTTPRequest<Data?>,
        responseCallbacks: Connect.ResponseCallbacks,
        eventLoop: NIOCore.EventLoop
    ) {
        self.request = request
        self.responseCallbacks = responseCallbacks
        self.eventLoop = eventLoop
    }

    /// Send outbound data over the stream.
    ///
    /// - parameter data: The data to send.
    func sendData(_ data: Data) {
        self.runOnEventLoop {
            if self.isClosed {
                return
            }

            if let context = self.context {
                context.writeAndFlush(self.wrapOutboundOut(.body(.byteBuffer(.init(data: data)))))
                    .cascade(to: nil)
            } else {
                self.pendingData.append(contentsOf: data)
            }
        }
    }

    /// Close the stream.
    func close() {
        self.runOnEventLoop {
            if self.isClosed {
                return
            }

            if let context = self.context {
                context.writeAndFlush(self.wrapOutboundOut(.end(nil))).cascade(to: nil)
            } else {
                self.pendingClose = .end(nil)
            }
        }
    }

    /// Cancel the stream, if currently active.
    func cancel() {
        self.runOnEventLoop {
            if self.isClosed {
                return
            }

            self.isClosed = true
            self.context?.close(promise: nil)
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

    // MARK: - ChannelInboundHandler

    typealias OutboundOut = NIOHTTP1.HTTPClientRequestPart
    typealias InboundIn = NIOHTTP1.HTTPClientResponsePart

    func channelActive(context: NIOCore.ChannelHandlerContext) {
        self.context = context
        if self.isClosed {
            return
        }

        var nioHeaders = NIOHTTP1.HTTPHeaders()
        nioHeaders.add(name: "Host", value: self.request.url.host!)
        nioHeaders.addNIOHeadersFromConnect(self.request.headers)

        let nioRequestHead = HTTPRequestHead.fromConnect(self.request, nioHeaders: nioHeaders)
        context.write(self.wrapOutboundOut(.head(nioRequestHead))).cascade(to: nil)

        if !self.pendingData.isEmpty {
            context.write(self.wrapOutboundOut(.body(.byteBuffer(.init(data: self.pendingData)))))
                .cascade(to: nil)
            self.pendingData = Data()
        }

        if let pendingClose = self.pendingClose {
            context.write(self.wrapOutboundOut(pendingClose)).cascade(to: nil)
            self.pendingClose = nil
        }

        context.flush()
        context.fireChannelActive()
    }

    func channelRead(context: NIOCore.ChannelHandlerContext, data: NIOCore.NIOAny) {
        if self.isClosed {
            return
        }

        let response = self.unwrapInboundIn(data)
        switch response {
        case .head(let head):
            self.receivedStatus = head.status
            self.responseCallbacks.receiveResponseHeaders(.fromNIOHeaders(head.headers))
            context.fireChannelRead(data)
        case .body(let byteBuffer):
            self.responseCallbacks.receiveResponseData(Data(buffer: byteBuffer))
            context.fireChannelRead(data)
        case .end(let trailers):
            self.responseCallbacks.receiveClose(
                self.receivedStatus.map { .fromNIOStatus($0) } ?? .ok,
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

    func userInboundEventTriggered(context: ChannelHandlerContext, event: Any) {
        guard event is NIOCore.IdleStateHandler.IdleStateEvent else {
            return context.fireUserInboundEventTriggered(event)
        }

        self.isClosed = true
        context.close(promise: nil)
        self.responseCallbacks.receiveClose(.deadlineExceeded, [:], ConnectError.deadlineExceeded())
    }
}
