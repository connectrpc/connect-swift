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

public protocol UnaryInterceptor: Interceptor {
    @Sendable
    func handleUnaryRequest(
        _ request: HTTPRequest<ProtobufMessage>,
        proceed: @escaping @Sendable (Result<HTTPRequest<ProtobufMessage>, ConnectError>) -> Void
    )

    @Sendable
    func handleUnaryRawRequest(
        _ request: HTTPRequest<Data?>,
        proceed: @escaping @Sendable (Result<HTTPRequest<Data?>, ConnectError>) -> Void
    )

    @Sendable
    func handleUnaryResponse(
        _ response: HTTPResponse<ProtobufMessage>,
        proceed: @escaping @Sendable (HTTPResponse<ProtobufMessage>) -> Void
    )

    @Sendable
    func handleUnaryRawResponse(
        _ response: HTTPResponse<Data?>,
        proceed: @escaping @Sendable (HTTPResponse<Data?>) -> Void
    )

    @Sendable
    func handleUnaryResponseMetrics(
        _ metrics: HTTPMetrics,
        proceed: @escaping @Sendable (HTTPMetrics) -> Void
    )
}

extension UnaryInterceptor {
    @Sendable
    public func handleUnaryRequest(
        _ request: HTTPRequest<ProtobufMessage>,
        proceed: @escaping @Sendable (Result<HTTPRequest<ProtobufMessage>, ConnectError>) -> Void
    ) {
        proceed(.success(request))
    }

    @Sendable
    public func handleUnaryRawRequest(
        _ request: HTTPRequest<Data?>,
        proceed: @escaping @Sendable (Result<HTTPRequest<Data?>, ConnectError>) -> Void
    ) {
        proceed(.success(request))
    }

    @Sendable
    public func handleUnaryResponse(
        _ response: HTTPResponse<ProtobufMessage>,
        proceed: @escaping @Sendable (HTTPResponse<ProtobufMessage>) -> Void
    ) {
        proceed(response)
    }

    @Sendable
    public func handleUnaryRawResponse(
        _ response: HTTPResponse<Data?>,
        proceed: @escaping @Sendable (HTTPResponse<Data?>) -> Void
    ) {
        proceed(response)
    }

    @Sendable
    public func handleUnaryResponseMetrics(
        _ metrics: HTTPMetrics,
        proceed: @escaping @Sendable (HTTPMetrics) -> Void
    ) {
        proceed(metrics)
    }
}
