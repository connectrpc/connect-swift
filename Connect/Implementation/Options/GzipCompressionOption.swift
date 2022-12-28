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

/// Provides an implementation of gzip for encoding/decoding, allowing the client to compress
/// and decompress requests/responses using gzip.
///
/// To compress outbound requests, specify the `GzipRequestOption`.
public struct GzipCompressionOption {
    public init() {}
}

extension GzipCompressionOption: ProtocolClientOption {
    public func apply(_ config: ProtocolClientConfig) -> ProtocolClientConfig {
        var compressionPools = config.compressionPools
        compressionPools[GzipCompressionPool.name()] = GzipCompressionPool()
        return config.clone(compressionPools: compressionPools)
    }
}
