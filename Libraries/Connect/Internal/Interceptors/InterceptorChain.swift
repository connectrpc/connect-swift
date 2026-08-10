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

/// Represents a chain of interceptors that is used for a single request/stream,
/// and orchestrates invoking each of them in the proper order.
final class InterceptorChain<T: Sendable>: Sendable {
    let interceptors: [T]

    init(_ interceptors: [T]) {
        self.interceptors = interceptors
    }
}

// MARK: - Async/await

/// Request paths are FIFO (plain iteration); response paths are LIFO (`reversed()`), so
/// `interceptors[0]` is outermost - the first to see an outbound request, the last to see an
/// inbound response.
extension InterceptorChain where T == any UnaryInterceptor {
    func executeRequest<Message: ProtobufMessage>(
        _ initial: HTTPRequest<Message>
    ) async throws -> HTTPRequest<Message> {
        var value = initial
        for interceptor in self.interceptors {
            value = try await interceptor.handleUnaryRequest(value)
        }
        return value
    }

    func executeRawRequest(_ initial: HTTPRequest<Data?>) async throws -> HTTPRequest<Data?> {
        var value = initial
        for interceptor in self.interceptors {
            value = try await interceptor.handleUnaryRawRequest(value)
        }
        return value
    }

    func executeRawResponse(_ initial: HTTPResponse) async -> HTTPResponse {
        var value = initial
        for interceptor in self.interceptors.reversed() {
            value = await interceptor.handleUnaryRawResponse(value)
        }
        return value
    }

    func executeResponse<Message: ProtobufMessage>(
        _ initial: ResponseMessage<Message>
    ) async -> ResponseMessage<Message> {
        var value = initial
        for interceptor in self.interceptors.reversed() {
            value = await interceptor.handleUnaryResponse(value)
        }
        return value
    }

    func executeMetrics(_ initial: HTTPMetrics) async -> HTTPMetrics {
        var value = initial
        for interceptor in self.interceptors.reversed() {
            value = await interceptor.handleResponseMetrics(value)
        }
        return value
    }
}

extension InterceptorChain where T == any StreamInterceptor {
    func executeStart(_ initial: HTTPRequest<Void>) async throws -> HTTPRequest<Void> {
        var value = initial
        for interceptor in self.interceptors {
            value = try await interceptor.handleStreamStart(value)
        }
        return value
    }

    func executeInput<Message: ProtobufMessage>(_ initial: Message) async -> Message {
        var value = initial
        for interceptor in self.interceptors {
            value = await interceptor.handleStreamInput(value)
        }
        return value
    }

    func executeRawInput(_ initial: Data) async -> Data {
        var value = initial
        for interceptor in self.interceptors {
            value = await interceptor.handleStreamRawInput(value)
        }
        return value
    }

    func executeRawResult(_ initial: StreamResult<Data>) async -> StreamResult<Data> {
        var value = initial
        for interceptor in self.interceptors.reversed() {
            value = await interceptor.handleStreamRawResult(value)
        }
        return value
    }

    func executeResult<Message: ProtobufMessage>(
        _ initial: StreamResult<Message>
    ) async -> StreamResult<Message> {
        var value = initial
        for interceptor in self.interceptors.reversed() {
            value = await interceptor.handleStreamResult(value)
        }
        return value
    }

    /// Duplicated from the `any UnaryInterceptor` extension: existentials do not self-conform, so
    /// a single `where T: Interceptor` overload cannot serve both chains.
    func executeMetrics(_ initial: HTTPMetrics) async -> HTTPMetrics {
        var value = initial
        for interceptor in self.interceptors.reversed() {
            value = await interceptor.handleResponseMetrics(value)
        }
        return value
    }
}
