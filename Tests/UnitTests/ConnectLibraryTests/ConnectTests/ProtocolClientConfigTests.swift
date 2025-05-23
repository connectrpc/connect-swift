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
    @Test("ProtocolClientConfig includes gzip compression by default and accepts gzip-compressed responses")
    func defaultResponseCompressionPoolIncludesGzip() {
        let config = ProtocolClientConfig(host: "https://connectrpc.com")
        #expect(config.responseCompressionPools[0] is GzipCompressionPool)
        #expect(config.acceptCompressionPoolNames() == ["gzip"])
    }

    @Test("RequestCompression compresses data when it exceeds the minimum byte threshold")
    func shouldCompressDataLargerThanMinBytes() {
        let data = Data(repeating: 0xa, count: 50)
        let compression = ProtocolClientConfig.RequestCompression(
            minBytes: 10, pool: GzipCompressionPool()
        )
        #expect(compression.shouldCompress(data))
    }

    @Test("RequestCompression skips compression when data is smaller than minimum byte threshold")
    func shouldNotCompressDataSmallerThanMinBytes() {
        let data = Data(repeating: 0xa, count: 50)
        let compression = ProtocolClientConfig.RequestCompression(
            minBytes: 100, pool: GzipCompressionPool()
        )
        #expect(!compression.shouldCompress(data))
    }

    @Test("ProtocolClientConfig correctly constructs URLs with various host configurations and RPC paths")
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

    @Test("ProtocolClientConfig appends ConnectInterceptor as the last interceptor when using Connect protocol")
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

    @Test("ProtocolClientConfig appends GRPCWebInterceptor as the last interceptor when using gRPC-Web protocol")
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

    @Test("ProtocolClientConfig appends custom protocol interceptor as the last interceptor when using custom protocol")
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

    @Test("ProtocolClientConfig enables unary GET requests for side-effect-free operations based on configuration")
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

    @Test("ProtocolClientConfig disables unary GET requests for idempotent operations with side effects")
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

    @Test("ProtocolClientConfig disables unary GET requests for operations with unknown side effects")
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
}
