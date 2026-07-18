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

@testable import Connect
import Foundation
import Testing

private final class NoopInterceptor1: UnaryInterceptor, StreamInterceptor {}

private final class NoopInterceptor2: UnaryInterceptor, StreamInterceptor {}

struct ProtocolClientConfigTests {
    @available(iOS 13, *)
    @Test
    func defaultResponseCompressionPoolIncludesGzip() {
        let config = ProtocolClientConfig(host: "https://connectrpc.com")
        #expect(config.responseCompressionPools[0] is GzipCompressionPool)
        #expect(config.acceptCompressionPoolNames() == ["gzip"])
    }

    @available(iOS 13, *)
    @Test
    func shouldCompressDataLargerThanMinBytes() {
        let data = Data(repeating: 0xa, count: 50)
        let compression = ProtocolClientConfig.RequestCompression(
            minBytes: 10, pool: GzipCompressionPool()
        )
        #expect(compression.shouldCompress(data))
    }

    @available(iOS 13, *)
    @Test
    func shouldNotCompressDataSmallerThanMinBytes() {
        let data = Data(repeating: 0xa, count: 50)
        let compression = ProtocolClientConfig.RequestCompression(
            minBytes: 100, pool: GzipCompressionPool()
        )
        #expect(!compression.shouldCompress(data))
    }

    @available(iOS 13, *)
    @Test
    func creatingURLsWithVariousHosts() {
        let rpcPath = Connectrpc_Conformance_V1_ConformanceServiceClient.Metadata.Methods.unary.path

        #expect(
            ProtocolClientConfig(host: "https://connectrpc.com")
                .createURL(forPath: rpcPath).absoluteString
            == "https://connectrpc.com/connectrpc.conformance.v1.ConformanceService/Unary"
        )
        #expect(
            ProtocolClientConfig(host: "https://connectrpc.com/")
                .createURL(forPath: rpcPath).absoluteString
            == "https://connectrpc.com/connectrpc.conformance.v1.ConformanceService/Unary"
        )
        #expect(
            ProtocolClientConfig(host: "https://connectrpc.com/a")
                .createURL(forPath: rpcPath).absoluteString
            == "https://connectrpc.com/a/connectrpc.conformance.v1.ConformanceService/Unary"
        )
        #expect(
            ProtocolClientConfig(host: "https://connectrpc.com/a/")
                .createURL(forPath: rpcPath).absoluteString
            == "https://connectrpc.com/a/connectrpc.conformance.v1.ConformanceService/Unary"
        )
        #expect(
            ProtocolClientConfig(host: "https://connectrpc.com/a/b/c")
                .createURL(forPath: rpcPath).absoluteString
            == "https://connectrpc.com/a/b/c/connectrpc.conformance.v1.ConformanceService/Unary"
        )
        #expect(
            ProtocolClientConfig(host: "https://connectrpc.com/a/b/c/")
                .createURL(forPath: rpcPath).absoluteString
            == "https://connectrpc.com/a/b/c/connectrpc.conformance.v1.ConformanceService/Unary"
        )
        #expect(
            ProtocolClientConfig(host: "connectrpc.com/a/b/c")
                .createURL(forPath: rpcPath).absoluteString
            == "connectrpc.com/a/b/c/connectrpc.conformance.v1.ConformanceService/Unary"
        )
    }

    @available(iOS 13, *)
    @Test
    func addsConnectInterceptorLastWhenUsingConnectProtocol() {
        let config = ProtocolClientConfig(
            host: "https://connectrpc.com",
            networkProtocol: .connect,
            interceptors: [InterceptorFactory { _ in NoopInterceptor1() }]
        )
        #expect(config.interceptors[0].createUnary(with: config) is NoopInterceptor1)
        #expect(config.interceptors[1].createUnary(with: config) is ConnectInterceptor)
        #expect(config.interceptors[0].createStream(with: config) is NoopInterceptor1)
        #expect(config.interceptors[1].createStream(with: config) is ConnectInterceptor)
    }

    @available(iOS 13, *)
    @Test
    func addsGRPCWebInterceptorLastWhenUsingGRPCWebProtocol() {
        let config = ProtocolClientConfig(
            host: "https://connectrpc.com",
            networkProtocol: .grpcWeb,
            interceptors: [InterceptorFactory { _ in NoopInterceptor1() }]
        )
        #expect(config.interceptors[0].createUnary(with: config) is NoopInterceptor1)
        #expect(config.interceptors[1].createUnary(with: config) is GRPCWebInterceptor)
        #expect(config.interceptors[0].createStream(with: config) is NoopInterceptor1)
        #expect(config.interceptors[1].createStream(with: config) is GRPCWebInterceptor)
    }

    @available(iOS 13, *)
    @Test
    func addsProtocolInterceptorLastWhenUsingOtherProtocol() {
        let config = ProtocolClientConfig(
            host: "https://connectrpc.com",
            networkProtocol: .custom(
                name: "custom", protocolInterceptor: InterceptorFactory { _ in NoopInterceptor2() }
            ),
            interceptors: [InterceptorFactory { _ in NoopInterceptor1() }]
        )
        #expect(config.interceptors[0].createUnary(with: config) is NoopInterceptor1)
        #expect(config.interceptors[1].createUnary(with: config) is NoopInterceptor2)
        #expect(config.interceptors[0].createStream(with: config) is NoopInterceptor1)
        #expect(config.interceptors[1].createStream(with: config) is NoopInterceptor2)
    }

    @available(iOS 13, *)
    @Test
    func unaryGETRequestWithNoSideEffects() {
        let request = HTTPRequest<Data?>(
            url: URL(string: "https://connectrpc.com")!,
            headers: Headers(),
            message: Data([0x0, 0x1, 0x2]),
            method: .post,
            trailers: nil,
            idempotencyLevel: .noSideEffects
        )
        #expect(ProtocolClientConfig(
            host: "https://connectrpc.com",
            networkProtocol: .connect,
            unaryGET: .alwaysEnabled
        ).shouldUseUnaryGET(for: request))
        #expect(ProtocolClientConfig(
            host: "https://connectrpc.com",
            networkProtocol: .connect,
            unaryGET: .enabledForLimitedPayloadSizes(maxBytes: 100)
        ).shouldUseUnaryGET(for: request))
        #expect(!ProtocolClientConfig(
            host: "https://connectrpc.com",
            networkProtocol: .connect,
            unaryGET: .enabledForLimitedPayloadSizes(maxBytes: 2)
        ).shouldUseUnaryGET(for: request))
        #expect(!ProtocolClientConfig(
            host: "https://connectrpc.com",
            networkProtocol: .connect,
            unaryGET: .disabled
        ).shouldUseUnaryGET(for: request))
    }

    @available(iOS 13, *)
    @Test
    func unaryGETRequestWithIdempotentSideEffects() {
        let request = HTTPRequest<Data?>(
            url: URL(string: "https://connectrpc.com")!,
            headers: Headers(),
            message: Data([0x0, 0x1, 0x2]),
            method: .post,
            trailers: nil,
            idempotencyLevel: .idempotent
        )
        #expect(!ProtocolClientConfig(
            host: "https://connectrpc.com",
            networkProtocol: .connect,
            unaryGET: .alwaysEnabled
        ).shouldUseUnaryGET(for: request))
        #expect(!ProtocolClientConfig(
            host: "https://connectrpc.com",
            networkProtocol: .connect,
            unaryGET: .enabledForLimitedPayloadSizes(maxBytes: 100)
        ).shouldUseUnaryGET(for: request))
        #expect(!ProtocolClientConfig(
            host: "https://connectrpc.com",
            networkProtocol: .connect,
            unaryGET: .enabledForLimitedPayloadSizes(maxBytes: 2)
        ).shouldUseUnaryGET(for: request))
        #expect(!ProtocolClientConfig(
            host: "https://connectrpc.com",
            networkProtocol: .connect,
            unaryGET: .disabled
        ).shouldUseUnaryGET(for: request))
    }

    @available(iOS 13, *)
    @Test
    func unaryGETRequestWithUnknownSideEffects() {
        let request = HTTPRequest<Data?>(
            url: URL(string: "https://connectrpc.com")!,
            headers: Headers(),
            message: Data([0x0, 0x1, 0x2]),
            method: .post,
            trailers: nil,
            idempotencyLevel: .unknown
        )
        #expect(!ProtocolClientConfig(
            host: "https://connectrpc.com",
            networkProtocol: .connect,
            unaryGET: .alwaysEnabled
        ).shouldUseUnaryGET(for: request))
        #expect(!ProtocolClientConfig(
            host: "https://connectrpc.com",
            networkProtocol: .connect,
            unaryGET: .enabledForLimitedPayloadSizes(maxBytes: 100)
        ).shouldUseUnaryGET(for: request))
        #expect(!ProtocolClientConfig(
            host: "https://connectrpc.com",
            networkProtocol: .connect,
            unaryGET: .enabledForLimitedPayloadSizes(maxBytes: 2)
        ).shouldUseUnaryGET(for: request))
        #expect(!ProtocolClientConfig(
            host: "https://connectrpc.com",
            networkProtocol: .connect,
            unaryGET: .disabled
        ).shouldUseUnaryGET(for: request))
    }

    @available(iOS 13, *)
    @Test
    func transformToGETWithoutRequestCompression() {
        let request = HTTPRequest<Data?>(
            url: URL(string: "https://connectrpc.com")!,
            headers: Headers(),
            message: Data([0x0, 0x1, 0x2]),
            method: .post,
            trailers: nil,
            idempotencyLevel: .noSideEffects
        )

        let config = ProtocolClientConfig(
            host: "https://connectrpc.com",
            networkProtocol: .connect,
            unaryGET: .alwaysEnabled
        )

        let requestWithoutCompression = config.transformToGETIfNeeded(request)

        #expect(requestWithoutCompression.method == .get)
        #expect(
            requestWithoutCompression.url.absoluteString
            == "https://connectrpc.com?connect=v1&base64=1&encoding=json&message=AAEC"
        )
    }

    @available(iOS 13, *)
    @Test
    func transformToGETUsesURLSafeBase64() {
        // Data bytes [0x3E, 0x3F, 0xBF, 0xFF] produce "+P+//w==" in standard base64
        // and "Pj-_vw" in raw URL-safe base64 (RFC 4648 §5)
        let request = HTTPRequest<Data?>(
            url: URL(string: "https://connectrpc.com")!,
            headers: Headers(),
            message: Data([0x3E, 0x3F, 0xBF, 0xFF]),
            method: .post,
            trailers: nil,
            idempotencyLevel: .noSideEffects
        )
        let config = ProtocolClientConfig(
            host: "https://connectrpc.com",
            networkProtocol: .connect,
            unaryGET: .alwaysEnabled
        )
        let getRequest = config.transformToGETIfNeeded(request)
        let url = getRequest.url.absoluteString
        // Must NOT contain + or / (standard base64 chars)
        #expect(!url.contains("+"), "URL must use URL-safe base64, not standard base64")
        #expect(!url.contains("/message/"), "URL must use URL-safe base64")
        // Must contain the URL-safe base64 encoded message
        #expect(url.contains("message=Pj-__w"), "Expected raw URL-safe base64 encoding")
    }

    @available(iOS 13, *)
    @Test
    func transformToGETWithRequestCompression() {
        let compressedRequest = HTTPRequest<Data?>(
            url: URL(string: "https://connectrpc.com")!,
            headers: [HeaderConstants.contentEncoding: ["gzip"]], // mimics inceptor behavior
            message: Data([0x0, 0x1, 0x2]),
            method: .post,
            trailers: nil,
            idempotencyLevel: .noSideEffects
        )

        let config = ProtocolClientConfig(
            host: "https://connectrpc.com",
            networkProtocol: .connect,
            unaryGET: .alwaysEnabled
        )

        let requestWithCompression = config.transformToGETIfNeeded(compressedRequest)

        #expect(requestWithCompression.method == .get)
        let expectedURL =
            "https://connectrpc.com?connect=v1&base64=1&compression=gzip&encoding=json&message=AAEC"
        #expect(requestWithCompression.url.absoluteString == expectedURL)
    }
}
