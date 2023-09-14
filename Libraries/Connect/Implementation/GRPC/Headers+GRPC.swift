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

extension Headers {
    /// Adds required headers to gRPC and gRPC-Web requests/streams.
    ///
    /// - parameter config: The configuration to use for adding headers (i.e., for compression
    ///                     headers).
    ///
    /// - returns: A set of updated headers.
    public func addingGRPCHeaders(using config: ProtocolClientConfig) -> Self {
        var headers = self
        headers[HeaderConstants.grpcAcceptEncoding] = config
            .acceptCompressionPoolNames()
        headers[HeaderConstants.grpcContentEncoding] = config.requestCompression
            .map { [$0.pool.name()] }
        headers[HeaderConstants.grpcTE] = ["trailers"]

        // Note that we do not comply with the recommended structure for user-agent:
        // https://github.com/grpc/grpc/blob/v1.51.1/doc/PROTOCOL-HTTP2.md#user-agents
        // But this behavior matches connect-web:
        // https://github.com/bufbuild/connect-web/blob/v0.4.0/packages/connect-core/src/grpc-web-create-request-header.ts#L33-L36
        // swiftlint:disable:previous line_length
        headers[HeaderConstants.xUserAgent] = ["@connectrpc/connect-swift"]
        return headers
    }
}
