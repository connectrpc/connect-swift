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

import Foundation

/// Configuration used to set up `ProtocolClientInterface` implementations.
public struct ProtocolClientConfig: Sendable {
    /// Configuration to use to determine when and how to send GET requests.
    public let getConfiguration: GETConfiguration
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
    /// List of interceptors that should be invoked with requests/responses.
    public let interceptors: [InterceptorInitializer]

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

    /// Configuration to use to determine when and how to send GET requests.
    public enum GETConfiguration: Sendable {
        /// Do not send idempotent requests using HTTP GET.
        case disabled
        /// Send idempotent requests using HTTP GET, regardless of their payload size.
        case alwaysEnabled
        /// Send idempotent requests using HTTP GET, but only if their payload size is less than
        /// or equal to a specific size.
        case enabledForLimitedPayloadSizes(maxBytes: Int)

        var isDisabled: Bool {
            if case .disabled = self {
                return true
            }
            return false
        }
    }

    public init(
        host: String,
        networkProtocol: NetworkProtocol = .connect,
        codec: Codec = JSONCodec(),
        getConfiguration: GETConfiguration = .disabled,
        requestCompression: RequestCompression? = nil,
        responseCompressionPools: [CompressionPool] = [GzipCompressionPool()],
        interceptors: [InterceptorInitializer] = []
    ) {
        self.getConfiguration = getConfiguration
        self.host = host
        self.networkProtocol = networkProtocol
        self.codec = codec
        self.requestCompression = requestCompression
        self.responseCompressionPools = responseCompressionPools

        switch networkProtocol {
        case .connect:
            self.interceptors = interceptors + [{ ConnectInterceptor(config: $0) }]
        case .grpcWeb:
            self.interceptors = interceptors + [{ GRPCWebInterceptor(config: $0) }]
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
    func createStreamInterceptorChain() -> InterceptorChain<StreamFunction> {
        return .init(
            self.interceptors.map { initialize in initialize(self).streamFunction() }
        )
    }

    func createUnaryInterceptorChain() -> InterceptorChain<UnaryFunction> {
        return .init(
            self.interceptors.map { initialize in initialize(self).unaryFunction() }
        )
    }
}
