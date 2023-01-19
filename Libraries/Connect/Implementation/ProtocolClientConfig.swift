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

import Foundation

/// Set of configuration (usually modified through `ClientOption` types) used to set up clients.
public struct ProtocolClientConfig {
    /// The target host (e.g., https://buf.build).
    public let host: String
    /// The client to use for performing requests.
    public let httpClient: HTTPClientInterface
    /// The minimum number of bytes that a request message should be for compression to be used.
    public let compressionMinBytes: Int?
    /// The compression type that should be used (e.g., "gzip").
    /// Requires a matching `compressionPools` entry.
    public let compressionName: String?
    /// Compression pools that provide support for the provided `compressionName`, as well as any
    /// other compression methods that need to be supported for inbound responses.
    public let compressionPools: [String: CompressionPool]
    /// Codec to use for serializing/deserializing requests/responses.
    public let codec: Codec
    /// Set of interceptors that should be invoked with requests/responses.
    public let interceptors: [(ProtocolClientConfig) -> Interceptor]

    public func clone(
        compressionMinBytes: Int? = nil,
        compressionName: String? = nil,
        compressionPools: [String: CompressionPool]? = nil,
        codec: Codec? = nil,
        interceptors: [(ProtocolClientConfig) -> Interceptor]? = nil
    ) -> Self {
        return .init(
            host: self.host,
            httpClient: self.httpClient,
            compressionMinBytes: compressionMinBytes ?? self.compressionMinBytes,
            compressionName: compressionName ?? self.compressionName,
            compressionPools: compressionPools ?? self.compressionPools,
            codec: codec ?? self.codec,
            interceptors: interceptors ?? self.interceptors
        )
    }
}

extension ProtocolClientConfig {
    func requestCompressionPool() -> CompressionPool? {
        return self.compressionName.flatMap { self.compressionPools[$0] }
    }

    func acceptCompressionPoolNames() -> [String] {
        return self.compressionPools.keys.filter { $0 != IdentityCompressionPool.name() }
    }

    func createInterceptorChain() -> InterceptorChain {
        return InterceptorChain(interceptors: self.interceptors, config: self)
    }
}
