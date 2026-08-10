// Copyright 2022-2025 The Connect Authors
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

/// Interceptor that can observe and/or mutate streams.
public protocol StreamInterceptor: Interceptor {
    /// Observe and/or mutate the creation of a stream and its associated headers.
    ///
    /// Order of invocation during a stream's lifecycle: 1
    ///
    /// - parameter request: The request being used to create the stream.
    /// - parameter proceed: Closure which must be called to pass (potentially altered) request
    ///                      to the next interceptor.
    @Sendable
    func handleStreamStart(
        _ request: HTTPRequest<Void>,
        proceed: @escaping @Sendable (Result<HTTPRequest<Void>, ConnectError>) -> Void
    )

    /// Observe and/or mutate a typed message to be sent to the server over a stream.
    ///
    /// Order of invocation during a stream's lifecycle: 2 (after `handleStreamStart()`)
    ///
    /// - parameter input: The message to be sent over the stream.
    /// - parameter proceed: Closure which must be called to pass (potentially altered) message
    ///                      to the next interceptor.
    @Sendable
    func handleStreamInput<Message: ProtobufMessage>(
        _ input: Message,
        proceed: @escaping @Sendable (Message) -> Void
    )

    /// Observe and/or mutate a message's serialized raw data to be sent to the server
    /// over a stream.
    ///
    /// Order of invocation during a stream's lifecycle: 3 (after `handleStreamInput()`)
    ///
    /// - parameter input: The raw data to be sent over the stream.
    /// - parameter proceed: Closure which must be called to pass (potentially altered) data
    ///                      to the next interceptor.
    @Sendable
    func handleStreamRawInput(
        _ input: Data,
        proceed: @escaping @Sendable (Data) -> Void
    )

    /// Observe and/or mutate a raw result (such as a serialized message) received from the server
    /// over a stream.
    ///
    /// Order of invocation during a stream's lifecycle: 4
    ///
    /// - parameter result: The raw result that was received over the stream.
    /// - parameter proceed: Closure which must be called to pass (potentially altered) result
    ///                      to the next interceptor.
    @Sendable
    func handleStreamRawResult(
        _ result: StreamResult<Data>,
        proceed: @escaping @Sendable (StreamResult<Data>) -> Void
    )

    /// Observe and/or mutate a typed deserialized result received from the server over a stream.
    ///
    /// Order of invocation during a stream's lifecycle: 5 (after `handleStreamRawResult()`)
    ///
    /// - parameter result: The deserialized result that was received over the stream.
    /// - parameter proceed: Closure which must be called to pass (potentially altered) message
    ///                      to the next interceptor.
    @Sendable
    func handleStreamResult<Message: ProtobufMessage>(
        _ result: StreamResult<Message>,
        proceed: @escaping @Sendable (StreamResult<Message>) -> Void
    )

    // MARK: - Async/await

    /// Observe and/or mutate the creation of a stream and its associated headers.
    ///
    /// These are the spellings the library invokes; each defaults to forwarding to the
    /// closure-based version above, so existing implementations keep being called unchanged.
    ///
    /// Order of invocation during a stream's lifecycle: 1
    ///
    /// - parameter request: The request being used to create the stream.
    /// - returns: The (potentially altered) request to pass to the next interceptor.
    /// - throws: A `ConnectError` to fail the stream without invoking further interceptors.
    @Sendable
    func handleStreamStart(_ request: HTTPRequest<Void>) async throws -> HTTPRequest<Void>

    /// Observe and/or mutate a typed message to be sent to the server over a stream.
    ///
    /// Order of invocation during a stream's lifecycle: 2 (after `handleStreamStart()`)
    ///
    /// - parameter input: The message to be sent over the stream.
    /// - returns: The (potentially altered) message to pass to the next interceptor.
    @Sendable
    func handleStreamInput<Message: ProtobufMessage>(_ input: Message) async -> Message

    /// Observe and/or mutate a message's serialized raw data to be sent to the server
    /// over a stream.
    ///
    /// Order of invocation during a stream's lifecycle: 3 (after `handleStreamInput()`)
    ///
    /// - parameter input: The raw data to be sent over the stream.
    /// - returns: The (potentially altered) data to pass to the next interceptor.
    @Sendable
    func handleStreamRawInput(_ input: Data) async -> Data

    /// Observe and/or mutate a raw result (such as a serialized message) received from the server
    /// over a stream.
    ///
    /// Order of invocation during a stream's lifecycle: 4
    ///
    /// - parameter result: The raw result that was received over the stream.
    /// - returns: The (potentially altered) result to pass to the next interceptor.
    @Sendable
    func handleStreamRawResult(_ result: StreamResult<Data>) async -> StreamResult<Data>

    /// Observe and/or mutate a typed deserialized result received from the server over a stream.
    ///
    /// Order of invocation during a stream's lifecycle: 5 (after `handleStreamRawResult()`)
    ///
    /// - parameter result: The deserialized result that was received over the stream.
    /// - returns: The (potentially altered) result to pass to the next interceptor.
    @Sendable
    func handleStreamResult<Message: ProtobufMessage>(
        _ result: StreamResult<Message>
    ) async -> StreamResult<Message>
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
    public func handleStreamRawResult(
        _ result: StreamResult<Data>,
        proceed: @escaping @Sendable (StreamResult<Data>) -> Void
    ) {
        proceed(result)
    }

    @Sendable
    public func handleStreamResult<Message: ProtobufMessage>(
        _ result: StreamResult<Message>,
        proceed: @escaping @Sendable (StreamResult<Message>) -> Void
    ) {
        proceed(result)
    }

    // MARK: - Async/await

    @Sendable
    public func handleStreamStart(_ request: HTTPRequest<Void>) async throws -> HTTPRequest<Void> {
        let result: Result<HTTPRequest<Void>, ConnectError> = await withSingleResume { resume in
            self.handleStreamStart(request, proceed: resume)
        }
        return try result.get()
    }

    @Sendable
    public func handleStreamInput<Message: ProtobufMessage>(_ input: Message) async -> Message {
        return await withSingleResume { resume in
            self.handleStreamInput(input, proceed: resume)
        }
    }

    @Sendable
    public func handleStreamRawInput(_ input: Data) async -> Data {
        return await withSingleResume { resume in
            self.handleStreamRawInput(input, proceed: resume)
        }
    }

    @Sendable
    public func handleStreamRawResult(_ result: StreamResult<Data>) async -> StreamResult<Data> {
        return await withSingleResume { resume in
            self.handleStreamRawResult(result, proceed: resume)
        }
    }

    @Sendable
    public func handleStreamResult<Message: ProtobufMessage>(
        _ result: StreamResult<Message>
    ) async -> StreamResult<Message> {
        return await withSingleResume { resume in
            self.handleStreamResult(result, proceed: resume)
        }
    }
}
