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
import ConnectGRPC
import Foundation

final class CrosstestClient {
    let description: String
    let protocolClient: ProtocolClient

    init(description: String, protocolClient: ProtocolClient) {
        self.description = description
        self.protocolClient = protocolClient
    }

    static func all(timeout: TimeInterval, responseDelay: TimeInterval?) -> [CrosstestClient] {
        let nioClient = CrosstestNIOHTTPClient(
            host: "https://localhost", port: 8081, timeout: timeout, responseDelay: responseDelay
        )
        let urlSessionClient = CrosstestURLSessionHTTPClient(
            timeout: timeout, delayAfterChallenge: responseDelay
        )
        let testMatrix: [(networkProtocol: NetworkProtocol, clients: [HTTPClientInterface])] = [
//            (.connect, [nioClient]),
            (.grpcWeb, [nioClient]),
//            (.grpc, [nioClient]), // URLSession client does not support gRPC
        ]
        let codecs: [Codec] = [JSONCodec(), ProtoCodec()]
        let host = "https://localhost:8081"
        return testMatrix.reduce(into: [CrosstestClient]()) { list, tuple in
            for client in tuple.clients {
                for codec in codecs {
                    list.append(CrosstestClient(
                        description: """
                        \(tuple.networkProtocol) + \(type(of: codec)) via \(type(of: client))
                        """,
                        protocolClient: ProtocolClient(
                            httpClient: client,
                            config: ProtocolClientConfig(
                                host: host,
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
