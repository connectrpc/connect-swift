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
import NIOConcurrencyHelpers
import NIOCore
import NIOHTTP1
import NIOHTTP2
import NIOPosix
import NIOSSL
import os.log

/// HTTP client powered by Swift NIO which supports trailers (unlike URLSession).
open class NIOHTTPClient: Connect.HTTPClientInterface, @unchecked Sendable {
    private lazy var bootstrap = self.createBootstrap()
    private let host: String
    private let lock = NIOConcurrencyHelpers.NIOLock()
    private let loopGroup = NIOPosix.MultiThreadedEventLoopGroup(numberOfThreads: 1)
    private let port: Int
    private let timeout: TimeInterval?
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
    /// - parameter host: Target host (e.g., `https://connectrpc.com`).
    /// - parameter port: Port to use for the connection. A default is provided based on whether a
    ///                   secure connection is being established to the host via HTTPS. If this
    ///                   parameter is omitted and the `host` parameter includes a port
    ///                   (e.g., `https://connectrpc.com:8080`), the host's port will be used.
    /// - parameter timeout: Optional timeout after which to terminate requests/streams if no
    ///                      activity has occurred in the request or response path.
    public init(host: String, port: Int? = nil, timeout: TimeInterval? = nil) {
        let baseURL = URL(string: host)!
        let useSSL = baseURL.scheme?.lowercased() == "https"
        self.host = baseURL.host!
        self.port = port ?? baseURL.port ?? (useSSL ? 443 : 80)
        self.timeout = timeout
        self.useSSL = useSSL
    }

    /// Called before the first request/stream is initialized, and the result is stored for reuse
    /// when creating new connections thereafter.
    /// This function may be used as an external customization point.
    ///
    /// - returns: The bootstrap that should be used for creating new connections.
    open func createBootstrap() -> NIOPosix.ClientBootstrap {
        let host = self.host
        let tlsConfiguration: NIOSSL.TLSConfiguration? = self.useSSL
        ? self.createTLSConfiguration(forHost: host)
        : nil

        return NIOPosix.ClientBootstrap(group: self.loopGroup)
            .channelOption(ChannelOptions.socket(IPPROTO_TCP, TCP_NODELAY), value: 1)
            .channelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .channelInitializer { channel in
                do {
                    let channelPipeline: EventLoopFuture<Void>
                    if let tlsConfiguration = tlsConfiguration {
                        let sslContext = try NIOSSL.NIOSSLContext(configuration: tlsConfiguration)
                        let sslHandler = try NIOSSL.NIOSSLClientHandler(
                            context: sslContext, serverHostname: host
                        )
                        channelPipeline = channel.pipeline
                            .addHandler(sslHandler)
                    } else {
                        channelPipeline = channel.pipeline
                            .addHandlers([])
                    }

                    return channelPipeline.flatMap {
                        return channel.configureHTTP2Pipeline(mode: .client) { channel in
                            return channel.eventLoop.makeSucceededVoidFuture()
                        }
                    }
                    .map { (_: NIOHTTP2.HTTP2StreamMultiplexer) in }
                } catch {
                    return channel.close(mode: .all)
                }
            }
    }

    /// Called during `createBootstrap()` to set up TLS if the client is configured to use SSL.
    /// This function may be used as an external customization point.
    ///
    /// - parameter host: The host for which to create the TLS configuration.
    ///
    /// - returns: The TLS configuration that should be used for creating new connections.
    open func createTLSConfiguration(forHost host: String) -> NIOSSL.TLSConfiguration {
        var tlsConfiguration = NIOSSL.TLSConfiguration.makeClientConfiguration()
        tlsConfiguration.applicationProtocols = ["h2"]
        return tlsConfiguration
    }

    // MARK: - HTTPClientInterface

    open func unary(
        request: Connect.HTTPRequest<Data?>,
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
                self?.startMultiplexChannel(
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
        return Connect.Cancelable { handler.cancel() }
    }

    open func stream(
        request: Connect.HTTPRequest<Data?>,
        responseCallbacks: Connect.ResponseCallbacks
    ) -> Connect.RequestCallbacks<Data> {
        let eventLoop = self.loopGroup.next()
        let handler = ConnectStreamChannelHandler(
            request: request,
            responseCallbacks: responseCallbacks,
            eventLoop: eventLoop
        )
        self.sendOrQueueRequest { [weak self] multiplexer in
            if let multiplexer = multiplexer {
                self?.startMultiplexChannel(
                    for: request.url, on: eventLoop, using: multiplexer, with: handler
                )
            } else {
                responseCallbacks.receiveClose(.unknown, [:], Error.disconnected)
            }
        }
        return .init(
            cancel: { handler.cancel() },
            sendData: { handler.sendData($0) },
            sendClose: { handler.close() }
        )
    }

    // MARK: - Private

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

    private func connectChannelAndMultiplexerIfNeeded() {
        guard case .disconnected = self.state else {
            return
        }

        self.state = .connecting
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
                    channel.closeFuture.whenComplete { [weak self] _ in
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

    private func flushOrFailPendingRequests(using multiplexer: NIOHTTP2.HTTP2StreamMultiplexer?) {
        for request in self.pendingRequests {
            request(multiplexer)
        }
        self.pendingRequests = []
    }

    private func startMultiplexChannel(
        for url: URL,
        on eventLoop: NIOCore.EventLoop,
        using multiplexer: NIOHTTP2.HTTP2StreamMultiplexer,
        with connectHandler: any NIOCore.ChannelInboundHandler
    ) {
        let handlers = self.createChannelHandlers(with: connectHandler)
        let promise = eventLoop.makePromise(of: NIOCore.Channel.self)
        multiplexer.createStreamChannel(promise: promise) { channel in
            return channel.pipeline.addHandlers(handlers)
        }
    }

    private func createChannelHandlers(
        with connectHandler: any NIOCore.ChannelInboundHandler
    ) -> [NIOCore.ChannelHandler] {
        var handlers: [NIOCore.ChannelHandler] = [
            self.useSSL
            ? HTTP2FramePayloadToHTTP1ClientCodec(httpProtocol: .https)
            : HTTP2FramePayloadToHTTP1ClientCodec(httpProtocol: .http),
            connectHandler,
        ]
        if let timeout = self.timeout {
            handlers.insert(
                IdleStateHandler(allTimeout: .milliseconds(Int64(timeout * 1_000.0))), at: 0
            )
        }
        return handlers
    }

    deinit {
        self.lock.withLock {
            if case .connected(let channel, _) = self.state {
                channel.close(mode: .all, promise: nil)
            }
        }
        try? self.loopGroup.syncShutdownGracefully()
    }
}
