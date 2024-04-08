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

import Foundation

/// Configuration used to set up `ProtocolClientInterface` implementations.
public struct ProtocolClientConfig: Sendable {
    /// Configuration used to determine when and how to send GET requests.
    public let unaryGET: UnaryGET
    /// Target host (e.g., `https://connectrpc.com`).
    public let host: String
    /// Protocol to use for requests and streams.
    public let networkProtocol: NetworkProtocol
    /// Codec to use for serializing requests and deserializing responses.
    public let codec: Codec
    /// Compression settings to use for oubound requests.
    public let requestCompression: RequestCompression?
    /// Compression pools that can be used to decompress responses based on
    /// response headers like `content-encoding`.
    public let responseCompressionPools: [CompressionPool]
    /// List of interceptor factories that should be used to produce interceptor chains.
    public let interceptors: [InterceptorFactory]
    /// Timeout that should be given to the server for requests to complete.
    public let timeout: TimeInterval?

    /// Configuration used to specify if/how requests should be compressed.
    public struct RequestCompression: Sendable {
        /// The minimum number of bytes that a request message should be for compression to be used.
        public let minBytes: Int
        /// The compression pool that should be used for compressing outbound requests.
        public let pool: CompressionPool

        public func shouldCompress(_ data: Data) -> Bool {
            return data.count >= self.minBytes
        }

        public init(minBytes: Int, pool: CompressionPool) {
            self.minBytes = minBytes
            self.pool = pool
        }
    }

    /// Configuration used to determine when and how to send GET requests.
    /// HTTP GET requests can be sent in place of unary HTTP POST requests when using
    /// the Connect protocol with idempotent RPCs that do not have side effects.
    /// Doing so makes it easier to cache responses.
    ///
    /// More info: https://connectrpc.com/docs/protocol#unary-get-request
    public enum UnaryGET: Sendable {
        /// Do not send idempotent requests using HTTP GET.
        case disabled
        /// Send idempotent requests using HTTP GET, regardless of their payload size.
        case alwaysEnabled
        /// Send idempotent requests using HTTP GET, but only if their payload size is less than
        /// or equal to a specific size.
        case enabledForLimitedPayloadSizes(maxBytes: Int)

        var isEnabled: Bool {
            switch self {
            case .alwaysEnabled, .enabledForLimitedPayloadSizes:
                return true
            case .disabled:
                return false
            }
        }
    }

    public init(
        host: String,
        networkProtocol: NetworkProtocol = .connect,
        codec: Codec = JSONCodec(),
        unaryGET: UnaryGET = .disabled,
        timeout: TimeInterval? = nil,
        requestCompression: RequestCompression? = nil,
        responseCompressionPools: [CompressionPool] = [GzipCompressionPool()],
        interceptors: [InterceptorFactory] = []
    ) {
        self.unaryGET = unaryGET
        self.host = host
        self.networkProtocol = networkProtocol
        self.codec = codec
        self.timeout = timeout
        self.requestCompression = requestCompression
        self.responseCompressionPools = responseCompressionPools

        switch networkProtocol {
        case .connect:
            self.interceptors = interceptors + [.init { ConnectInterceptor(config: $0) }]
        case .grpcWeb:
            self.interceptors = interceptors + [.init { GRPCWebInterceptor(config: $0) }]
        case .custom(_, let protocolInterceptor):
            self.interceptors = interceptors + [protocolInterceptor]
        }
    }
}

extension ProtocolClientConfig {
    public func acceptCompressionPoolNames() -> [String] {
        return self.responseCompressionPools.map { $0.name() }
    }

    public func responseCompressionPool(forName name: String) -> CompressionPool? {
        return self.responseCompressionPools.first { $0.name() == name }
    }
}

// MARK: - Internal

extension ProtocolClientConfig {
    func createUnaryInterceptorChain() -> InterceptorChain<any UnaryInterceptor> {
        return .init(self.interceptors.compactMap { $0.createUnary(with: self) })
    }

    func createStreamInterceptorChain() -> InterceptorChain<any StreamInterceptor> {
        return .init(self.interceptors.compactMap { $0.createStream(with: self) })
    }

    func createURL(forPath path: String) -> URL {
        return URL(string: self.host)!.appendingPathComponent(path)
    }
}
