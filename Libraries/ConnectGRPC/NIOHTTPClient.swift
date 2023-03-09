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
    typealias OutboundOut = HTTPClientRequestPart
    typealias InboundIn = HTTPClientResponsePart

    func channelActive(context: ChannelHandlerContext) {
        print("**Active: \(context)")

//        var headers = NIOHTTP1.HTTPHeaders()
//        headers.add(name: "Content-Type", value: "text/plain")
//        headers.add(name: "Accept", value: "application/json")
//        headers.add(name: "User-Agent", value: "curl/7.86.0")
////        headers.add(name: "Content-Length", value: "0")
//        //        for (name, value) in request.headers {
//        //            headers.add(name: name, value: value.joined(separator: ","))
//        //        }
//
//        let requestHead = HTTPRequestHead(
//            version: .http1_1,
//            method: .GET,
//            uri: "/bin/astro.php?lon=113.2&lat=23.1&ac=0&unit=metric&output=json&tzshift=0",
//            headers: headers
//        )
//        context.channel.writeAndFlush(self.wrapOutboundOut(.head(requestHead)))
//        context.channel.writeAndFlush(NIOAny(HTTPClientRequestPart.body(.byteBuffer(.init()))))
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
            print("Closing channel.")
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

    public init(host: String, port: Int? = nil) {
        let baseURL = URL(string: host)!
        let host = baseURL.host!
        let useSSL = baseURL.scheme?.lowercased() == "https"
        let port = port ?? (useSSL ? 443 : 80)
        print("**using SSL: \(useSSL) on port \(port)")
        let bootstrap = NIOPosix.ClientBootstrap(group: self.loopGroup)
            .channelOption(NIOCore.ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .channelInitializer { channel in
                if useSSL {
                    do {
                        let tlsHandler = try NIOSSLClientHandler(
                            context: try NIOSSLContext(configuration: .clientDefault),
                            serverHostname: host
                        )
                        return channel.pipeline
                            .addHandler(tlsHandler)
                            .flatMap { _ in
                                channel.configureHTTP2SecureUpgrade(
                                    h2ChannelConfigurator: { channel in
                                        return channel.configureHTTP2Pipeline(
                                            mode: .client, inboundStreamInitializer: nil
                                        )
                                        .map { _ in }
                                    },
                                    http1ChannelConfigurator: { channel in
                                        return channel.pipeline.eventLoop.makeSucceededVoidFuture()
                                    }
                                )
                            }
                            .flatMap { channel.pipeline.addHTTPClientHandlers() }
                            .flatMap { channel.pipeline.addHandler(ConnectChannelHandler()) }
                    } catch {
                        return channel.close(mode: .all)
                    }
                } else {
                    return channel.pipeline
                        .addHTTPClientHandlers()
                        .flatMap { channel.pipeline.addHandler(ConnectChannelHandler()) }
                }
            }

        bootstrap.connect(host: host, port: port).whenComplete { [weak self] result in
            switch result {
            case .success(let channel):
                print("**Connected to channel \(channel)")
                self?.channel = channel
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
        guard let channel = self.channel else {
            onResponse(.init(code: .unknown, headers: [:], message: nil, trailers: [:], error: nil, tracingInfo: nil))
            return .init(cancel: {})
        }

        var headers = NIOHTTP1.HTTPHeaders()
        headers.add(name: "Content-Type", value: request.contentType)
//        headers.add(name: "accept", value: "application/json")
        headers.add(name: "Content-Length", value: "\(request.message?.count ?? 0)")
        for (name, value) in request.headers {
            headers.add(name: name, value: value.joined(separator: ","))
        }

        print(channel.isActive)
        let requestHead = HTTPRequestHead(
            version: .http1_1,
            method: .POST,
            uri: request.url.path,
            headers: headers
        )
        channel.write(NIOAny(HTTPClientRequestPart.head(requestHead)))
        channel.writeAndFlush(NIOAny(HTTPClientRequestPart.body(.byteBuffer(.init(bytes: request.message!)))))
//        channel.writeAndFlush(NIOAny(HTTPClientRequestPart.body(.byteBuffer(.init(bytes: request.message!)))))
//        channel.writeAndFlush(NIOAny(HTTPClientRequestPart.end(nil)))
//            .whenComplete { result in
//                print("**Sent: \(result)")
//            }
//        channel.closeFuture.whenComplete({ result in
//            print("**Closed: \(result)")
//        })
//
//            .flatMap {  }
//            .flatMap {  }

        return .init(cancel: {})
    }

    open func stream(
        request: Connect.HTTPRequest,
        responseCallbacks: Connect.ResponseCallbacks
    ) -> Connect.RequestCallbacks {
        fatalError()
    }
}
