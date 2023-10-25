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
    func handleStreamInput<Message: ProtobufMessage>(
        _ input: Message,
        proceed: @escaping @Sendable (Message) -> Void
    )

    @Sendable
    func handleStreamRawInput(
        _ input: Data,
        proceed: @escaping @Sendable (Data) -> Void
    )

    @Sendable
    func handleStreamResult<Message: ProtobufMessage>(
        _ result: StreamResult<Message>,
        proceed: @escaping @Sendable (StreamResult<Message>) -> Void
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
    public func handleStreamInput<Message: ProtobufMessage>(
        _ input: Message,
        proceed: @escaping @Sendable (Message) -> Void
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
    public func handleStreamResult<Message: ProtobufMessage>(
        _ result: StreamResult<Message>,
        proceed: @escaping @Sendable (StreamResult<Message>) -> Void
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
