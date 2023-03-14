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
import Dispatch
import Foundation
import NIOCore
import NIOPosix
import NIOHTTP1
import NIOHTTP2
import NIOSSL
import os.log

/// HTTP client powered by Swift NIO and also supports trailers (unlike URLSession).
open class NIOHTTPClient: Connect.HTTPClientInterface {
    private lazy var bootstrap: NIOPosix.ClientBootstrap = {
        NIOPosix.ClientBootstrap(group: self.loopGroup)
            .channelOption(ChannelOptions.socket(IPPROTO_TCP, TCP_NODELAY), value: 1)
            .channelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .channelInitializer { channel in
                do {
                    if self.useSSL {
                        var tlsConfiguration = NIOSSL.TLSConfiguration.makeClientConfiguration()
                        tlsConfiguration.applicationProtocols = ["h2"]
                        let sslContext = try NIOSSL.NIOSSLContext(configuration: tlsConfiguration)
                        let sslHandler = try NIOSSL.NIOSSLClientHandler(
                            context: sslContext, serverHostname: self.host
                        )
                        return channel.pipeline
                            .addHandler(sslHandler)
                            .flatMap {
                                return channel.configureHTTP2Pipeline(mode: .client) { channel in
                                    return channel.eventLoop.makeSucceededVoidFuture()
                                }
                            }
                            .map { (_: NIOHTTP2.HTTP2StreamMultiplexer) in }
                    } else {
                        return channel
                            .configureHTTP2Pipeline(mode: .client) { channel in
                                return channel.eventLoop.makeSucceededVoidFuture()
                            }
                            .map { (_: NIOHTTP2.HTTP2StreamMultiplexer) in }
                    }
                } catch {
                    return channel.close(mode: .all)
                }
            }
    }()
    private let host: String
    private let loopGroup = NIOPosix.MultiThreadedEventLoopGroup(numberOfThreads: 1)
    private let port: Int
    private let reconnectDelay: () -> TimeInterval
    private let useSSL: Bool

    private var pendingRequests = [(NIOHTTP2.HTTP2StreamMultiplexer) -> Void]()
    private var state = State.disconnected

    private enum State {
        case disconnected
        case connected(channel: NIOCore.Channel, multiplexer: NIOHTTP2.HTTP2StreamMultiplexer)
    }

    /// Designated initializer for the client.
    ///
    /// - parameter host: Target host (e.g., `https://buf.build`).
    /// - parameter port: Port to use for the connection. Default is provided based on whether a
    ///                   secure connection is being established to the host via HTTPS.
    /// - parameter reconnectDelay: Closure to use for calculating the delay that should be used
    ///                             when reconnecting if an error with the connection is
    ///                             encountered. Invoked each time a connection is being
    ///                             re-established.
    public init(
        host: String,
        port: Int? = nil,
        reconnectDelay: @escaping () -> TimeInterval = { 1.0 }
    ) {
        let baseURL = URL(string: host)!
        let useSSL = baseURL.scheme?.lowercased() == "https"
        self.host = baseURL.host!
        self.port = port ?? (useSSL ? 443 : 80)
        self.reconnectDelay = reconnectDelay
        self.useSSL = useSSL
        self.connect()
    }

    private func connect() {
        self.bootstrap
            .connect(host: self.host, port: self.port)
            .flatMap { channel -> EventLoopFuture<(Channel, HTTP2StreamMultiplexer)> in
                return channel.pipeline
                    .handler(type: HTTP2StreamMultiplexer.self)
                    .map { (channel, $0) }
            }
            .whenComplete { [weak self] result in
                switch result {
                case .success((let channel, let multiplexer)):
                    channel.closeFuture.whenComplete { result in
                        self?.state = .disconnected
                        self?.scheduleReconnect()
                    }
                    self?.state = .connected(channel: channel, multiplexer: multiplexer)
                    self?.flushPendingRequests(using: multiplexer)

                case .failure(let error):
                    os_log(.error, "NIOHTTPClient disconnected: %@", "\(error)")
                    self?.state = .disconnected
                    self?.scheduleReconnect()
                }
            }
    }

    private func queuePendingRequest(send: @escaping (NIOHTTP2.HTTP2StreamMultiplexer) -> Void) {
        self.pendingRequests.append(send)
    }

    private func flushPendingRequests(using multiplexer: NIOHTTP2.HTTP2StreamMultiplexer) {
        for request in self.pendingRequests {
            request(multiplexer)
        }
        self.pendingRequests = []
    }

    private func scheduleReconnect() {
        let delayMS = Int(self.reconnectDelay() * 1_000.0)
        os_log(.error, "NIOHTTPClient reconnecting after: %@", "\(delayMS)ms")
        DispatchQueue.global(qos: .userInitiated)
            .asyncAfter(deadline: .now() + .milliseconds(delayMS)) { [weak self] in
                self?.connect()
            }
    }

    private func startChannel(
        for url: URL,
        on eventLoop: NIOCore.EventLoop,
        using multiplexer: NIOHTTP2.HTTP2StreamMultiplexer,
        with connectHandler: any NIOCore.ChannelInboundHandler
    ) {
        let codec = self.useSSL
        ? HTTP2FramePayloadToHTTP1ClientCodec(httpProtocol: .https)
        : HTTP2FramePayloadToHTTP1ClientCodec(httpProtocol: .http)
        let promise = eventLoop.makePromise(of: NIOCore.Channel.self)
        multiplexer.createStreamChannel(promise: promise) { channel in
            return channel.pipeline.addHandlers([
                codec,
                connectHandler,
            ])
        }
    }

    deinit {
        if case .connected(let channel, _) = self.state {
            try? channel.closeFuture.wait()
        }
        try? self.loopGroup.syncShutdownGracefully()
    }

    open func unary(
        request: Connect.HTTPRequest,
        onMetrics: @escaping @Sendable (Connect.HTTPMetrics) -> Void,
        onResponse: @escaping @Sendable (Connect.HTTPResponse) -> Void
    ) -> Connect.Cancelable {
        let eventLoop = self.loopGroup.next()
        let handler = ConnectUnaryChannelHandler(
            request: request,
            eventLoop: eventLoop,
            onMetrics: onMetrics,
            onResponse: onResponse
        )
        switch self.state {
        case .connected(_, let multiplexer):
            self.startChannel(for: request.url, on: eventLoop, using: multiplexer, with: handler)
        case .disconnected:
            self.queuePendingRequest { [weak self] multiplexer in
                self?.startChannel(
                    for: request.url, on: eventLoop, using: multiplexer, with: handler
                )
            }
        }
        return .init(cancel: handler.cancel)
    }

    open func stream(
        request: Connect.HTTPRequest,
        responseCallbacks: Connect.ResponseCallbacks
    ) -> Connect.RequestCallbacks {
        let eventLoop = self.loopGroup.next()
        let handler = ConnectStreamChannelHandler(
            request: request,
            responseCallbacks: responseCallbacks,
            eventLoop: eventLoop
        )
        switch self.state {
        case .connected(_, let multiplexer):
            self.startChannel(for: request.url, on: eventLoop, using: multiplexer, with: handler)
        case .disconnected:
            self.queuePendingRequest { [weak self] multiplexer in
                self?.startChannel(
                    for: request.url, on: eventLoop, using: multiplexer, with: handler
                )
            }
        }
        return .init(
            sendData: handler.sendData,
            sendClose: { handler.close(trailers: nil) }
        )
    }
}
