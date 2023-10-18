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

// swiftlint:disable number_separator

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
        let nioClient8081 = ConformanceNIOHTTPClient(
            host: "https://localhost", port: 8081, timeout: timeout
        )
        let nioClient8083 = ConformanceNIOHTTPClient(
            host: "https://localhost", port: 8083, timeout: timeout
        )
        // swiftlint:disable:next large_tuple
        let matrix: [(
            networkProtocol: NetworkProtocol,
            httpClients: [HTTPClientInterface],
            codecs: [Codec],
            port: Int
        )] = [
            // Port 8081 is used to test against connect-go
            (.connect, [urlSessionClient, nioClient8081], [JSONCodec(), ProtoCodec()], 8081),
            (.grpcWeb, [urlSessionClient, nioClient8081], [JSONCodec(), ProtoCodec()], 8081),
            // URLSession does not support gRPC
            (.grpc, [nioClient8081], [JSONCodec(), ProtoCodec()], 8081),
            // gRPC should also be tested against grpc-go, which runs on port 8083
            (.grpc, [nioClient8083], [ProtoCodec()], 8083),
        ]
        return matrix.reduce(into: [Self]()) { configurations, tuple in
            for httpClient in tuple.httpClients {
                for codec in tuple.codecs {
                    configurations.append(.init(
                        description: """
                        \(tuple.networkProtocol) + \(type(of: codec)) via \(type(of: httpClient)) \
                        on port \(tuple.port)
                        """,
                        protocolClient: ProtocolClient(
                            httpClient: httpClient,
                            config: ProtocolClientConfig(
                                host: "https://localhost:\(tuple.port)",
                                networkProtocol: tuple.networkProtocol,
                                codec: codec,
                                getConfiguration: .alwaysEnabled,
                                requestCompression: .init(minBytes: 10, pool: GzipCompressionPool())
                            )
                        )
                    ))
                }
            }
        }
    }
}
