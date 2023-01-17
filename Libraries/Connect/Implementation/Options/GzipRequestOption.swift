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

/// Enables gzip compression on outbound requests using a compression pool registered for "gzip"
/// (i.e., the one provided by `GzipCompressionOption`).
///
/// If present, `ProtocolClientInterface` implementations should respect the
/// `ProtocolClientConfig.compressionMinBytes` configuration when compressing.
public struct GzipRequestOption {
    private let compressionMinBytes: Int

    /// Designated initializer.
    ///
    /// - parameter compressionMinBytes: If a request message payload exceeds this number of bytes,
    ///                                  the payload will be compressed. Smaller payload messages
    ///                                  will not be compressed.
    public init(compressionMinBytes: Int) {
        self.compressionMinBytes = compressionMinBytes
    }
}

extension GzipRequestOption: ProtocolClientOption {
    public func apply(_ config: ProtocolClientConfig) -> ProtocolClientConfig {
        return config.clone(
            compressionMinBytes: self.compressionMinBytes,
            compressionName: GzipCompressionPool.name()
        )
    }
}
