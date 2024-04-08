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

@testable import Connect
import Foundation
import XCTest

private final class NoopInterceptor1: UnaryInterceptor, StreamInterceptor {}

private final class NoopInterceptor2: UnaryInterceptor, StreamInterceptor {}

final class ProtocolClientConfigTests: XCTestCase {
    func testDefaultResponseCompressionPoolIncludesGzip() {
        let config = ProtocolClientConfig(host: "https://connectrpc.com")
        XCTAssertTrue(config.responseCompressionPools[0] is GzipCompressionPool)
        XCTAssertEqual(config.acceptCompressionPoolNames(), ["gzip"])
    }

    func testShouldCompressDataLargerThanMinBytes() {
        let data = Data(repeating: 0xa, count: 50)
        let compression = ProtocolClientConfig.RequestCompression(
            minBytes: 10, pool: GzipCompressionPool()
        )
        XCTAssertTrue(compression.shouldCompress(data))
    }

    func testShouldNotCompressDataSmallerThanMinBytes() {
        let data = Data(repeating: 0xa, count: 50)
        let compression = ProtocolClientConfig.RequestCompression(
            minBytes: 100, pool: GzipCompressionPool()
        )
        XCTAssertFalse(compression.shouldCompress(data))
    }

    func testCreatingURLsWithVariousHosts() {
        let rpcPath = Connectrpc_Conformance_V1_ConformanceServiceClient.Metadata.Methods.unary.path

        XCTAssertEqual(
            ProtocolClientConfig(host: "https://connectrpc.com")
                .createURL(forPath: rpcPath).absoluteString,
            "https://connectrpc.com/connectrpc.conformance.v1.ConformanceService/Unary"
        )
        XCTAssertEqual(
            ProtocolClientConfig(host: "https://connectrpc.com/")
                .createURL(forPath: rpcPath).absoluteString,
            "https://connectrpc.com/connectrpc.conformance.v1.ConformanceService/Unary"
        )
        XCTAssertEqual(
            ProtocolClientConfig(host: "https://connectrpc.com/a")
                .createURL(forPath: rpcPath).absoluteString,
            "https://connectrpc.com/a/connectrpc.conformance.v1.ConformanceService/Unary"
        )
        XCTAssertEqual(
            ProtocolClientConfig(host: "https://connectrpc.com/a/")
                .createURL(forPath: rpcPath).absoluteString,
            "https://connectrpc.com/a/connectrpc.conformance.v1.ConformanceService/Unary"
        )
        XCTAssertEqual(
            ProtocolClientConfig(host: "https://connectrpc.com/a/b/c")
                .createURL(forPath: rpcPath).absoluteString,
            "https://connectrpc.com/a/b/c/connectrpc.conformance.v1.ConformanceService/Unary"
        )
        XCTAssertEqual(
            ProtocolClientConfig(host: "https://connectrpc.com/a/b/c/")
                .createURL(forPath: rpcPath).absoluteString,
            "https://connectrpc.com/a/b/c/connectrpc.conformance.v1.ConformanceService/Unary"
        )
        XCTAssertEqual(
            ProtocolClientConfig(host: "connectrpc.com/a/b/c")
                .createURL(forPath: rpcPath).absoluteString,
            "connectrpc.com/a/b/c/connectrpc.conformance.v1.ConformanceService/Unary"
        )
    }

    func testAddsConnectInterceptorLastWhenUsingConnectProtocol() {
        let config = ProtocolClientConfig(
            host: "https://connectrpc.com",
            networkProtocol: .connect,
            interceptors: [InterceptorFactory { _ in NoopInterceptor1() }]
        )
        XCTAssertTrue(config.interceptors[0].createUnary(with: config) is NoopInterceptor1)
        XCTAssertTrue(config.interceptors[1].createUnary(with: config) is ConnectInterceptor)
        XCTAssertTrue(config.interceptors[0].createStream(with: config) is NoopInterceptor1)
        XCTAssertTrue(config.interceptors[1].createStream(with: config) is ConnectInterceptor)
    }

    func testAddsGRPCWebInterceptorLastWhenUsingGRPCWebProtocol() {
        let config = ProtocolClientConfig(
            host: "https://connectrpc.com",
            networkProtocol: .grpcWeb,
            interceptors: [InterceptorFactory { _ in NoopInterceptor1() }]
        )
        XCTAssertTrue(config.interceptors[0].createUnary(with: config) is NoopInterceptor1)
        XCTAssertTrue(config.interceptors[1].createUnary(with: config) is GRPCWebInterceptor)
        XCTAssertTrue(config.interceptors[0].createStream(with: config) is NoopInterceptor1)
        XCTAssertTrue(config.interceptors[1].createStream(with: config) is GRPCWebInterceptor)
    }

    func testAddsProtocolInterceptorLastWhenUsingOtherProtocol() {
        let config = ProtocolClientConfig(
            host: "https://connectrpc.com",
            networkProtocol: .custom(
                name: "custom", protocolInterceptor: InterceptorFactory { _ in NoopInterceptor2() }
            ),
            interceptors: [InterceptorFactory { _ in NoopInterceptor1() }]
        )
        XCTAssertTrue(config.interceptors[0].createUnary(with: config) is NoopInterceptor1)
        XCTAssertTrue(config.interceptors[1].createUnary(with: config) is NoopInterceptor2)
        XCTAssertTrue(config.interceptors[0].createStream(with: config) is NoopInterceptor1)
        XCTAssertTrue(config.interceptors[1].createStream(with: config) is NoopInterceptor2)
    }

    func testUnaryGETRequestWithNoSideEffects() {
        let request = HTTPRequest<Data?>(
            url: URL(string: "https://connectrpc.com")!,
            headers: Headers(),
            message: Data([0x0, 0x1, 0x2]),
            method: .post,
            trailers: nil,
            idempotencyLevel: .noSideEffects
        )
        XCTAssertTrue(ProtocolClientConfig(
            host: "https://connectrpc.com",
            networkProtocol: .connect,
            unaryGET: .alwaysEnabled
        ).shouldUseUnaryGET(for: request))
        XCTAssertTrue(ProtocolClientConfig(
            host: "https://connectrpc.com",
            networkProtocol: .connect,
            unaryGET: .enabledForLimitedPayloadSizes(maxBytes: 100)
        ).shouldUseUnaryGET(for: request))
        XCTAssertFalse(ProtocolClientConfig(
            host: "https://connectrpc.com",
            networkProtocol: .connect,
            unaryGET: .enabledForLimitedPayloadSizes(maxBytes: 2)
        ).shouldUseUnaryGET(for: request))
        XCTAssertFalse(ProtocolClientConfig(
            host: "https://connectrpc.com",
            networkProtocol: .connect,
            unaryGET: .disabled
        ).shouldUseUnaryGET(for: request))
    }

    func testUnaryGETRequestWithIdempotentSideEffects() {
        let request = HTTPRequest<Data?>(
            url: URL(string: "https://connectrpc.com")!,
            headers: Headers(),
            message: Data([0x0, 0x1, 0x2]),
            method: .post,
            trailers: nil,
            idempotencyLevel: .idempotent
        )
        XCTAssertFalse(ProtocolClientConfig(
            host: "https://connectrpc.com",
            networkProtocol: .connect,
            unaryGET: .alwaysEnabled
        ).shouldUseUnaryGET(for: request))
        XCTAssertFalse(ProtocolClientConfig(
            host: "https://connectrpc.com",
            networkProtocol: .connect,
            unaryGET: .enabledForLimitedPayloadSizes(maxBytes: 100)
        ).shouldUseUnaryGET(for: request))
        XCTAssertFalse(ProtocolClientConfig(
            host: "https://connectrpc.com",
            networkProtocol: .connect,
            unaryGET: .enabledForLimitedPayloadSizes(maxBytes: 2)
        ).shouldUseUnaryGET(for: request))
        XCTAssertFalse(ProtocolClientConfig(
            host: "https://connectrpc.com",
            networkProtocol: .connect,
            unaryGET: .disabled
        ).shouldUseUnaryGET(for: request))
    }

    func testUnaryGETRequestWithUnknownSideEffects() {
        let request = HTTPRequest<Data?>(
            url: URL(string: "https://connectrpc.com")!,
            headers: Headers(),
            message: Data([0x0, 0x1, 0x2]),
            method: .post,
            trailers: nil,
            idempotencyLevel: .unknown
        )
        XCTAssertFalse(ProtocolClientConfig(
            host: "https://connectrpc.com",
            networkProtocol: .connect,
            unaryGET: .alwaysEnabled
        ).shouldUseUnaryGET(for: request))
        XCTAssertFalse(ProtocolClientConfig(
            host: "https://connectrpc.com",
            networkProtocol: .connect,
            unaryGET: .enabledForLimitedPayloadSizes(maxBytes: 100)
        ).shouldUseUnaryGET(for: request))
        XCTAssertFalse(ProtocolClientConfig(
            host: "https://connectrpc.com",
            networkProtocol: .connect,
            unaryGET: .enabledForLimitedPayloadSizes(maxBytes: 2)
        ).shouldUseUnaryGET(for: request))
        XCTAssertFalse(ProtocolClientConfig(
            host: "https://connectrpc.com",
            networkProtocol: .connect,
            unaryGET: .disabled
        ).shouldUseUnaryGET(for: request))
    }
}
