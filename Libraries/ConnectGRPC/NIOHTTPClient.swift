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
import NIOPosix
import NIOHTTP1
import NIOHTTP2
import NIOSSL

private final class ConnectChannelHandler: NIOCore.ChannelInboundHandler {
    private let request: Connect.HTTPRequest
    private let onMetrics: (Connect.HTTPMetrics) -> Void
    private let onResponse: (Connect.HTTPResponse) -> Void

    typealias OutboundOut = NIOHTTP1.HTTPClientRequestPart
    typealias InboundIn = NIOHTTP1.HTTPClientResponsePart

    init(
        request: Connect.HTTPRequest,
        onMetrics: @escaping (Connect.HTTPMetrics) -> Void,
        onResponse: @escaping (Connect.HTTPResponse) -> Void
    ) {
        self.request = request
        self.onMetrics = onMetrics
        self.onResponse = onResponse
    }

    func cancel() {
        #warning("todo")
    }

    func channelActive(context: ChannelHandlerContext) {
        print("**Active: \(context)")

        var headers = NIOHTTP1.HTTPHeaders()
        headers.add(name: "Content-Type", value: self.request.contentType)
        headers.add(name: "Content-Length", value: "\(self.request.message?.count ?? 0)")
        headers.add(name: "Host", value: self.request.url.host!)
        for (name, value) in self.request.headers {
            headers.add(name: name, value: value.joined(separator: ","))
        }

        let requestHead = HTTPRequestHead(
            version: .http1_1,
            method: .POST,
            uri: self.request.url.path,
            headers: headers
        )
        context.write(self.wrapOutboundOut(.head(requestHead))).cascade(to: nil)
        if let message = self.request.message {
            context.write(self.wrapOutboundOut(.body(.byteBuffer(.init(bytes: message)))))
                .cascade(to: nil)
        }
        context.writeAndFlush(self.wrapOutboundOut(.end(.init()))).cascade(to: nil)
        context.fireChannelActive()
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let clientResponse = self.unwrapInboundIn(data)

        switch clientResponse {
        case .head(let responseHead):
            print("Received head: \(responseHead)")
        case .body(let byteBuffer):
            let string = String(buffer: byteBuffer)
            print("Response data:")
            print(string)
        case .end:
            print("Trailers received")
//            context.close(promise: nil)
        }
    }

    func errorCaught(context: ChannelHandlerContext, error: Error) {
        print("error: ", error)

        // As we are not really interested getting notified on success or failure we just pass nil as promise to
        // reduce allocations.
        context.close(promise: nil)
    }
}

open class NIOHTTPClient: Connect.HTTPClientInterface {
    private var channel: NIOCore.Channel?
    private let loopGroup = NIOPosix.MultiThreadedEventLoopGroup(numberOfThreads: 1)
    private var multiplexer: NIOHTTP2.HTTP2StreamMultiplexer?

    public init(host: String, port: Int? = nil) {
        let baseURL = URL(string: host)!
        let host = baseURL.host!
        let useSSL = baseURL.scheme?.lowercased() == "https"
        let port = port ?? (useSSL ? 443 : 80)
        let bootstrap = NIOPosix.ClientBootstrap(group: self.loopGroup)
            .channelOption(NIOCore.ChannelOptions.socketOption(.so_reuseaddr), value: 1)
//            .channelInitializer { channel in
//                return channel.configureForConnect(url: baseURL)
//            }

        bootstrap.connect(host: host, port: port).whenComplete { [weak self] result in
            switch result {
            case .success(let channel):
                print("**Connected to channel \(channel)")
                self?.channel = channel
                self?.multiplexer = .init(
                    mode: .client, channel: channel, inboundStreamInitializer: nil
                )
            case .failure(let error):
                print("**Failed: \(error)")
            }
        }
    }

    deinit {
        try? self.channel?.closeFuture.wait()
        try? self.loopGroup.syncShutdownGracefully()
    }

    open func unary(
        request: Connect.HTTPRequest,
        onMetrics: @escaping @Sendable (Connect.HTTPMetrics) -> Void,
        onResponse: @escaping @Sendable (Connect.HTTPResponse) -> Void
    ) -> Connect.Cancelable {
        guard let multiplexer = self.multiplexer else {
            onResponse(.init(code: .unknown, headers: [:], message: nil, trailers: [:], error: nil, tracingInfo: nil))
            return .init(cancel: {})
        }

        let connectHandler = ConnectChannelHandler(
            request: request,
            onMetrics: onMetrics,
            onResponse: onResponse
        )
        multiplexer.createStreamChannel(promise: nil) { channel in
            return channel.configureForConnect(
                url: request.url,
                connectHandler: connectHandler
            )
        }
        return .init(cancel: connectHandler.cancel)
    }

    open func stream(
        request: Connect.HTTPRequest,
        responseCallbacks: Connect.ResponseCallbacks
    ) -> Connect.RequestCallbacks {
        #warning("todo")
        fatalError()
    }
}

private extension NIOCore.Channel {
    func configureForConnect(
        url: URL, connectHandler: any ChannelInboundHandler
    ) -> EventLoopFuture<Void> {
        let useSSL = url.scheme?.lowercased() == "https"
        guard useSSL else {
            return self.pipeline
                .addHTTPClientHandlers()
                .flatMap { self.pipeline.addHandler(connectHandler) }
                .flatMap { self.pipeline.addHandler(HTTP2FramePayloadToHTTP1ClientCodec(httpProtocol: .http)) }
        }

        do {
            let tlsHandler = try NIOSSLClientHandler(
                context: try NIOSSLContext(configuration: .clientDefault),
                serverHostname: url.host!
            )
            return self.pipeline.addHandlers([HTTP2FramePayloadToHTTP1ClientCodec(httpProtocol: .https), connectHandler], position: .last)
            return self.pipeline
                .addHandler(tlsHandler)
                .flatMap { self.pipeline.addHTTPClientHandlers() }
                .flatMap { self.pipeline.addHandler(connectHandler) }
                .flatMap { self.pipeline.addHandler(HTTP2FramePayloadToHTTP1ClientCodec(httpProtocol: .https)) }
//                .flatMap {
//                    self.configureHTTP2SecureUpgrade(
//                        h2ChannelConfigurator: { channel in
//                            return channel.configureHTTP2Pipeline(
//                                mode: .client, inboundStreamInitializer: nil
//                            )
//                            .map { _ in }
//                        },
//                        http1ChannelConfigurator: { channel in
//                            return channel.pipeline.eventLoop.makeSucceededVoidFuture()
//                        }
//                    )
//                }
        } catch {
            return self.close(mode: .all)
        }
    }
}
