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

extension Headers {
    /// This should not be considered part of Connect's public/stable interface, and is subject
    /// to change. When the compiler supports it, this should be package-internal.
    ///
    /// Adds required headers to gRPC and gRPC-Web requests/streams.
    ///
    /// - parameter config: The configuration to use for adding headers (i.e., for compression
    ///                     headers).
    /// - parameter grpcWeb: Should be true if using gRPC-Web, false if gRPC.
    ///
    /// - returns: A set of updated headers.
    public func addingGRPCHeaders(using config: ProtocolClientConfig, grpcWeb: Bool) -> Self {
        var headers = self
        headers[HeaderConstants.grpcAcceptEncoding] = config
            .acceptCompressionPoolNames()
        headers[HeaderConstants.grpcContentEncoding] = config.requestCompression
            .map { [$0.pool.name()] }
        if let timeout = config.timeout {
            headers[HeaderConstants.grpcTimeout] = ["\(Int(timeout * 1_000))m"]
        }
        if grpcWeb {
            headers[HeaderConstants.contentType] = [
                "application/grpc-web+\(config.codec.name())",
            ]
        } else {
            headers[HeaderConstants.contentType] = [
                "application/grpc+\(config.codec.name())",
            ]
            headers[HeaderConstants.grpcTE] = ["trailers"]
        }

        // Note that we do not comply with the recommended structure for user-agent:
        // https://github.com/grpc/grpc/blob/v1.51.1/doc/PROTOCOL-HTTP2.md#user-agents
        // But this behavior matches connect-web:
        // https://github.com/bufbuild/connect-web/blob/v0.4.0/packages/connect-core/src/grpc-web-create-request-header.ts#L33-L36
        // swiftlint:disable:previous line_length
        headers[HeaderConstants.xUserAgent] = ["@connectrpc/connect-swift"]
        return headers
    }
}
