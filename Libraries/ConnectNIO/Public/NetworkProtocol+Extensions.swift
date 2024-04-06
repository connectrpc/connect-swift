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

import Connect

extension NetworkProtocol {
    /// The gRPC protocol:
    /// https://github.com/grpc/grpc/blob/master/doc/PROTOCOL-HTTP2.md
    ///
    /// IMPORTANT: This protocol must be used in conjunction with an HTTP client that supports
    /// trailers, such as the `NIOHTTPClient` included in this library.
    public static var grpc: Self {
        return .custom(
            name: "gRPC",
            protocolInterceptor: InterceptorFactory { GRPCInterceptor(config: $0) }
        )
    }
}
