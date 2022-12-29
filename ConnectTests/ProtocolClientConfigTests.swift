//
// Copyright 2022 Buf Technologies, Inc.
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
//

@testable import Connect
import Foundation
import XCTest

final class ProtocolClientConfigTests: XCTestCase {
    func testCompressionPoolsWithIdentityAndGzip() {
        var config = ProtocolClientConfig(
            target: "https://buf.build", httpClient: URLSessionHTTPClient(), codec: ProtoCodec()
        )
        config = IdentityCompressionOption().apply(config)
        config = GzipCompressionOption().apply(config)

        XCTAssertTrue(config.compressionPools["identity"] is IdentityCompressionPool)
        XCTAssertTrue(config.compressionPools["gzip"] is GzipCompressionPool)

        // Identity is omitted from "accept" since it's a no-op
        XCTAssertEqual(config.acceptCompressionPoolNames(), ["gzip"])
    }

    func testGzipRequestOptionUsesGzipCompressionPool() {
        var config = ProtocolClientConfig(
            target: "https://buf.build", httpClient: URLSessionHTTPClient(), codec: ProtoCodec()
        )
        config = GzipCompressionOption().apply(config)
        config = GzipRequestOption(compressionMinBytes: 10).apply(config)
        XCTAssertTrue(config.requestCompressionPool() is GzipCompressionPool)
    }

    func testInterceptorsOptionAddsToExistingInterceptorsIfCalledMultipleTimes() {
        class NoopInterceptor: Interceptor {
            func unaryFunction() -> UnaryFunction {
                return .init(requestFunction: { $0 }, responseFunction: { $0 })
            }

            func streamFunction() -> StreamFunction {
                return .init(
                    requestFunction: { $0 },
                    requestDataFunction: { $0 },
                    streamResultFunc: { $0 }
                )
            }

            init(config: ProtocolClientConfig) {}
        }

        final class InterceptorA: NoopInterceptor {}
        final class InterceptorB: NoopInterceptor {}

        var config = ProtocolClientConfig(
            target: "https://buf.build", httpClient: URLSessionHTTPClient(), codec: ProtoCodec()
        )
        config = InterceptorsOption(interceptors: [InterceptorA.init]).apply(config)
        config = InterceptorsOption(interceptors: [InterceptorB.init]).apply(config)

        let interceptors = config.interceptors.map { $0(config) }
        XCTAssertTrue(interceptors[0] is InterceptorA)
        XCTAssertTrue(interceptors[1] is InterceptorB)
    }

    func testJSONClientOptionSetsJSONCodec() {
        var config = ProtocolClientConfig(
            target: "https://buf.build", httpClient: URLSessionHTTPClient(), codec: ProtoCodec()
        )
        config = JSONClientOption().apply(config)
        XCTAssertTrue(config.codec is JSONCodec)
    }

    func testProtoClientOptionSetsProtoCodec() {
        var config = ProtocolClientConfig(
            target: "https://buf.build", httpClient: URLSessionHTTPClient(), codec: JSONCodec()
        )
        config = ProtoClientOption().apply(config)
        XCTAssertTrue(config.codec is ProtoCodec)
    }
}
