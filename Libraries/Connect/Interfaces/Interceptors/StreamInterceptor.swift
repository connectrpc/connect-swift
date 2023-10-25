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

public protocol StreamInterceptor: Interceptor {
    @Sendable
    func handleStreamStart(
        _ request: HTTPRequest<Void>,
        proceed: @escaping @Sendable (Result<HTTPRequest<Void>, ConnectError>) -> Void
    )

    @Sendable
    func handleStreamInput(
        _ input: ProtobufMessage,
        proceed: @escaping @Sendable (ProtobufMessage) -> Void
    )

    @Sendable
    func handleStreamRawInput(
        _ input: Data,
        proceed: @escaping @Sendable (Data) -> Void
    )

    @Sendable
    func handleStreamResponse(
        _ response: HTTPResponse<Void>,
        proceed: @escaping @Sendable (HTTPResponse<Void>) -> Void
    )

    @Sendable
    func handleStreamResponseMetrics(
        _ metrics: HTTPMetrics,
        proceed: @escaping @Sendable (HTTPMetrics) -> Void
    )

    @Sendable
    func handleStreamResult(
        _ result: StreamResult<ProtobufMessage>,
        proceed: @escaping @Sendable (StreamResult<ProtobufMessage>) -> Void
    )

    @Sendable
    func handleStreamRawResult(
        _ result: StreamResult<Data>,
        proceed: @escaping @Sendable (StreamResult<Data>) -> Void
    )
}

extension StreamInterceptor {
    @Sendable
    public func handleStreamStart(
        _ request: HTTPRequest<Void>,
        proceed: @escaping @Sendable (Result<HTTPRequest<Void>, ConnectError>) -> Void
    ) {
        proceed(.success(request))
    }

    @Sendable
    public func handleStreamInput(
        _ input: ProtobufMessage,
        proceed: @escaping @Sendable (ProtobufMessage) -> Void
    ) {
        proceed(input)
    }

    @Sendable
    public func handleStreamRawInput(
        _ input: Data,
        proceed: @escaping @Sendable (Data) -> Void
    ) {
        proceed(input)
    }

    @Sendable
    public func handleStreamResponse(
        _ response: HTTPResponse<Void>,
        proceed: @escaping @Sendable (HTTPResponse<Void>) -> Void
    ) {
        proceed(response)
    }

    @Sendable
    public func handleStreamResponseMetrics(
        _ metrics: HTTPMetrics,
        proceed: @escaping @Sendable (HTTPMetrics) -> Void
    ) {
        proceed(metrics)
    }

    @Sendable
    public func handleStreamResult(
        _ result: StreamResult<ProtobufMessage>,
        proceed: @escaping @Sendable (StreamResult<ProtobufMessage>) -> Void
    ) {
        proceed(result)
    }

    @Sendable
    public func handleStreamRawResult(
        _ result: StreamResult<Data>,
        proceed: @escaping @Sendable (StreamResult<Data>) -> Void
    ) {
        proceed(result)
    }
}
