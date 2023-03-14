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
import NIOConcurrencyHelpers
import NIOCore
import NIOPosix
import NIOHTTP1
import NIOHTTP2
import NIOSSL
import os.log

/// HTTP client powered by Swift NIO and also supports trailers (unlike URLSession).
open class NIOHTTPClient: Connect.HTTPClientInterface {
    private lazy var bootstrap: NIOPosix.ClientBootstrap = {
        let host = self.host
        let useSSL = self.useSSL
        return NIOPosix.ClientBootstrap(group: self.loopGroup)
            .channelOption(ChannelOptions.socket(IPPROTO_TCP, TCP_NODELAY), value: 1)
            .channelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .channelInitializer { channel in
                do {
                    if useSSL {
                        var tlsConfiguration = NIOSSL.TLSConfiguration.makeClientConfiguration()
                        tlsConfiguration.applicationProtocols = ["h2"]
                        let sslContext = try NIOSSL.NIOSSLContext(configuration: tlsConfiguration)
                        let sslHandler = try NIOSSL.NIOSSLClientHandler(
                            context: sslContext, serverHostname: host
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
    private let lock = NIOConcurrencyHelpers.NIOLock()
    private let loopGroup = NIOPosix.MultiThreadedEventLoopGroup(numberOfThreads: 1)
    private let port: Int
    private let useSSL: Bool

    private var pendingRequests = [(NIOHTTP2.HTTP2StreamMultiplexer?) -> Void]()
    private var state = State.disconnected

    private enum State {
        case disconnected
        case connecting
        case connected(channel: NIOCore.Channel, multiplexer: NIOHTTP2.HTTP2StreamMultiplexer)
    }

    private enum Error: Swift.Error {
        case disconnected
    }

    /// Designated initializer for the client.
    ///
    /// - parameter host: Target host (e.g., `https://buf.build`).
    /// - parameter port: Port to use for the connection. Default is provided based on whether a
    ///                   secure connection is being established to the host via HTTPS.
    public init(host: String, port: Int? = nil) {
        let baseURL = URL(string: host)!
        let useSSL = baseURL.scheme?.lowercased() == "https"
        self.host = baseURL.host!
        self.port = port ?? (useSSL ? 443 : 80)
        self.useSSL = useSSL
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
        self.sendOrQueueRequest { [weak self] multiplexer in
            if let multiplexer = multiplexer {
                self?.startChannel(
                    for: request.url, on: eventLoop, using: multiplexer, with: handler
                )
            } else {
                onResponse(.init(
                    code: .unknown,
                    headers: [:],
                    message: nil,
                    trailers: [:],
                    error: Error.disconnected,
                    tracingInfo: nil
                ))
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
        self.sendOrQueueRequest { [weak self] multiplexer in
            if let multiplexer = multiplexer {
                self?.startChannel(
                    for: request.url, on: eventLoop, using: multiplexer, with: handler
                )
            } else {
                responseCallbacks.receiveClose(.unknown, [:], Error.disconnected)
            }
        }
        return .init(
            sendData: handler.sendData,
            sendClose: { handler.close(trailers: nil) }
        )
    }

    // MARK: - Private

    private func connectChannelAndMultiplexerIfNeeded() {
        guard case .disconnected = self.state else {
            return
        }

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
                        self?.lock.withLock { self?.state = .disconnected }
                    }
                    self?.lock.withLock {
                        self?.state = .connected(channel: channel, multiplexer: multiplexer)
                        self?.flushOrFailPendingRequests(using: multiplexer)
                    }
                case .failure(let error):
                    os_log(.error, "NIOHTTPClient disconnected: %@", "\(error)")
                    self?.lock.withLock {
                        self?.state = .disconnected
                        self?.flushOrFailPendingRequests(using: nil)
                    }
                }
            }
    }

    private func sendOrQueueRequest(send: @escaping (NIOHTTP2.HTTP2StreamMultiplexer?) -> Void) {
        self.lock.withLock {
            switch self.state {
            case .connected(_, let multiplexer):
                send(multiplexer)
            case .connecting, .disconnected:
                self.pendingRequests.append(send)
                self.connectChannelAndMultiplexerIfNeeded()
            }
        }
    }

    private func flushOrFailPendingRequests(using multiplexer: NIOHTTP2.HTTP2StreamMultiplexer?) {
        for request in self.pendingRequests {
            request(multiplexer)
        }
        self.pendingRequests = []
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
        self.lock.withLock {
            if case .connected(let channel, _) = self.state {
                try? channel.closeFuture.wait()
            }
        }
        try? self.loopGroup.syncShutdownGracefully()
    }
}
