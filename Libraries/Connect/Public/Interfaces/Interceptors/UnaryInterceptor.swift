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

/// Interceptor that can observe and/or mutate unary requests.
public protocol UnaryInterceptor: Interceptor {
    /// Observe and/or mutate a typed request message to be sent to the server.
    ///
    /// Order of invocation during a request's lifecycle: 1
    ///
    /// - parameter request: The typed request and message to be sent.
    /// - parameter proceed: Closure which must be called to pass (potentially altered) request
    ///                      to the next interceptor.
    @Sendable
    func handleUnaryRequest<Message: ProtobufMessage>(
        _ request: HTTPRequest<Message>,
        proceed: @escaping @Sendable (Result<HTTPRequest<Message>, ConnectError>) -> Void
    )

    /// Observe and/or mutate a raw (serialized) request to be sent to the server.
    ///
    /// Order of invocation during a request's lifecycle: 2 (after `handleUnaryRequest()`)
    ///
    /// - parameter request: The raw (serialized) request to be sent.
    /// - parameter proceed: Closure which must be called to pass (potentially altered) request
    ///                      to the next interceptor.
    @Sendable
    func handleUnaryRawRequest(
        _ request: HTTPRequest<Data?>,
        proceed: @escaping @Sendable (Result<HTTPRequest<Data?>, ConnectError>) -> Void
    )

    /// Observe and/or mutate a raw (serialized) response received from the server.
    ///
    /// Order of invocation during a request's lifecycle: 3
    ///
    /// - parameter response: The raw (serialized) response that was received.
    /// - parameter proceed: Closure which must be called to pass (potentially altered) response
    ///                      to the next interceptor.
    @Sendable
    func handleUnaryRawResponse(
        _ response: HTTPResponse,
        proceed: @escaping @Sendable (HTTPResponse) -> Void
    )

    /// Observe and/or mutate a typed (deserialized) response received from the server.
    ///
    /// Order of invocation during a request's lifecycle: 4 (after `handleUnaryRawResponse()`)
    ///
    /// - parameter response: The typed (deserialized) response received from the server.
    /// - parameter proceed: Closure which must be called to pass (potentially altered) response
    ///                      to the next interceptor.
    @Sendable
    func handleUnaryResponse<Message: ProtobufMessage>(
        _ response: ResponseMessage<Message>,
        proceed: @escaping @Sendable (ResponseMessage<Message>) -> Void
    )

    // MARK: - Async/await

    /// Observe and/or mutate a typed request message to be sent to the server.
    ///
    /// These are the spellings the library invokes; each defaults to forwarding to the
    /// closure-based version above, so existing implementations keep being called unchanged.
    ///
    /// Order of invocation during a request's lifecycle: 1
    ///
    /// - parameter request: The typed request and message to be sent.
    /// - returns: The (potentially altered) request to pass to the next interceptor.
    /// - throws: A `ConnectError` to fail the request without invoking further interceptors.
    @Sendable
    func handleUnaryRequest<Message: ProtobufMessage>(
        _ request: HTTPRequest<Message>
    ) async throws -> HTTPRequest<Message>

    /// Observe and/or mutate a raw (serialized) request to be sent to the server.
    ///
    /// Order of invocation during a request's lifecycle: 2 (after `handleUnaryRequest()`)
    ///
    /// - parameter request: The raw (serialized) request to be sent.
    /// - returns: The (potentially altered) request to pass to the next interceptor.
    /// - throws: A `ConnectError` to fail the request without invoking further interceptors.
    @Sendable
    func handleUnaryRawRequest(_ request: HTTPRequest<Data?>) async throws -> HTTPRequest<Data?>

    /// Observe and/or mutate a raw (serialized) response received from the server.
    ///
    /// Order of invocation during a request's lifecycle: 3
    ///
    /// - parameter response: The raw (serialized) response that was received.
    /// - returns: The (potentially altered) response to pass to the next interceptor.
    @Sendable
    func handleUnaryRawResponse(_ response: HTTPResponse) async -> HTTPResponse

    /// Observe and/or mutate a typed (deserialized) response received from the server.
    ///
    /// Order of invocation during a request's lifecycle: 4 (after `handleUnaryRawResponse()`)
    ///
    /// - parameter response: The typed (deserialized) response received from the server.
    /// - returns: The (potentially altered) response to pass to the next interceptor.
    @Sendable
    func handleUnaryResponse<Message: ProtobufMessage>(
        _ response: ResponseMessage<Message>
    ) async -> ResponseMessage<Message>
}

extension UnaryInterceptor {
    @Sendable
    public func handleUnaryRequest<Message: ProtobufMessage>(
        _ request: HTTPRequest<Message>,
        proceed: @escaping @Sendable (Result<HTTPRequest<Message>, ConnectError>) -> Void
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
    public func handleUnaryRawResponse(
        _ response: HTTPResponse,
        proceed: @escaping @Sendable (HTTPResponse) -> Void
    ) {
        proceed(response)
    }

    @Sendable
    public func handleUnaryResponse<Message: ProtobufMessage>(
        _ response: ResponseMessage<Message>,
        proceed: @escaping @Sendable (ResponseMessage<Message>) -> Void
    ) {
        proceed(response)
    }

    // MARK: - Async/await

    @Sendable
    public func handleUnaryRequest<Message: ProtobufMessage>(
        _ request: HTTPRequest<Message>
    ) async throws -> HTTPRequest<Message> {
        let result: Result<HTTPRequest<Message>, ConnectError> = await withSingleResume { resume in
            self.handleUnaryRequest(request, proceed: resume)
        }
        return try result.get()
    }

    @Sendable
    public func handleUnaryRawRequest(
        _ request: HTTPRequest<Data?>
    ) async throws -> HTTPRequest<Data?> {
        let result: Result<HTTPRequest<Data?>, ConnectError> = await withSingleResume { resume in
            self.handleUnaryRawRequest(request, proceed: resume)
        }
        return try result.get()
    }

    @Sendable
    public func handleUnaryRawResponse(_ response: HTTPResponse) async -> HTTPResponse {
        return await withSingleResume { resume in
            self.handleUnaryRawResponse(response, proceed: resume)
        }
    }

    @Sendable
    public func handleUnaryResponse<Message: ProtobufMessage>(
        _ response: ResponseMessage<Message>
    ) async -> ResponseMessage<Message> {
        return await withSingleResume { resume in
            self.handleUnaryResponse(response, proceed: resume)
        }
    }
}
