// Copyright 2022-2023 The Connect Authors
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

private struct NoopInterceptor: Interceptor {
    func unaryFunction() -> UnaryFunction {
        return UnaryFunction(requestFunction: { $1($0) }, responseFunction: { $1($0) })
    }

    func streamFunction() -> StreamFunction {
        return StreamFunction(
            requestFunction: { $1($0) },
            requestDataFunction: { $1($0) },
            streamResultFunction: { $1($0) }
        )
    }

    init(config: ProtocolClientConfig) {}
}

final class ProtocolClientConfigTests: XCTestCase {
    func testDefaultResponseCompressionPoolIncludesGzip() {
        let config = ProtocolClientConfig(host: "https://buf.build")
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

    func testAddsConnectInterceptorLastWhenUsingConnectProtocol() {
        let config = ProtocolClientConfig(
            host: "https://buf.build",
            networkProtocol: .connect,
            interceptors: [{ NoopInterceptor(config: $0) }]
        )
        XCTAssertTrue(config.interceptors[0](config) is NoopInterceptor)
        XCTAssertTrue(config.interceptors[1](config) is ConnectInterceptor)
    }

    func testAddsGRPCWebInterceptorLastWhenUsingGRPCWebProtocol() {
        let config = ProtocolClientConfig(
            host: "https://buf.build",
            networkProtocol: .grpcWeb,
            interceptors: [{ NoopInterceptor(config: $0) }]
        )
        XCTAssertTrue(config.interceptors[0](config) is NoopInterceptor)
        XCTAssertTrue(config.interceptors[1](config) is GRPCWebInterceptor)
    }
}
