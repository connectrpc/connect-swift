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
import ConnectNIO
import Foundation

/// Represents a specific configuration with which to run a suite of conformance tests.
final class ConformanceConfiguration {
    let description: String
    let protocolClient: ProtocolClient

    private init(description: String, protocolClient: ProtocolClient) {
        self.description = description
        self.protocolClient = protocolClient
    }

    /// Configures a list of configurations that can be used to run a comprehensive
    /// suite of conformance tests.
    ///
    /// - parameter timeout: Timeout to apply to the client.
    ///
    /// - returns: A list of configurations to use for conformance tests.
    static func all(timeout: TimeInterval) -> [ConformanceConfiguration] {
        let urlSessionClient = ConformanceURLSessionHTTPClient(timeout: timeout)
        let nioClient = ConformanceNIOHTTPClient(
            // swiftlint:disable:next number_separator
            host: "https://localhost", port: 8081, timeout: timeout
        )
        let matrix: [(networkProtocol: NetworkProtocol, httpClients: [HTTPClientInterface])] = [
            (.connect, [urlSessionClient, nioClient]),
            (.grpcWeb, [urlSessionClient, nioClient]),
            (.grpc, [nioClient]), // URLSession client does not support gRPC
        ]
        let codecs: [Codec] = [JSONCodec(), ProtoCodec()]
        return matrix.reduce(into: []) { configurations, tuple in
            for httpClient in tuple.httpClients {
                for codec in codecs {
                    configurations.append(.init(
                        description: """
                        \(tuple.networkProtocol) + \(type(of: codec)) via \(type(of: httpClient))
                        """,
                        protocolClient: ProtocolClient(
                            httpClient: httpClient,
                            config: ProtocolClientConfig(
                                host: "https://localhost:8081",
                                networkProtocol: tuple.networkProtocol,
                                codec: codec,
                                requestCompression: .init(minBytes: 10, pool: GzipCompressionPool())
                            )
                        )
                    ))
                }
            }
        }
    }
}
