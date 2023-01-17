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

/// Provides a no-op default implementation for encoding/decoding.
public struct IdentityCompressionOption {
    public init() {}
}

extension IdentityCompressionOption: ProtocolClientOption {
    public func apply(_ config: ProtocolClientConfig) -> ProtocolClientConfig {
        var compressionPools = config.compressionPools
        compressionPools[IdentityCompressionPool.name()] = IdentityCompressionPool()
        return config.clone(compressionPools: compressionPools)
    }
}
