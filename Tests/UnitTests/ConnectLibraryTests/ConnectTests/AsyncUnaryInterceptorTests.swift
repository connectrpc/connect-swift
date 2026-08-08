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

@testable import Connect
import Foundation
import Testing

private typealias TestMessage = Connectrpc_Conformance_V1_UnaryResponse

struct AsyncUnaryInterceptorTests {
    // MARK: - Ordering

    @Test
    func requestPathIsFIFOAndResponsePathIsLIFO() async throws {
        let steps = Locked([String]())
        let chain = InterceptorChain<any UnaryInterceptor>([
            TrackingInterceptor(id: "a", steps: steps),
            TrackingInterceptor(id: "b", steps: steps),
        ])

        _ = try await chain.executeRequest(Self.makeRequest())
        _ = await chain.executeRawResponse(Self.makeResponse())

        #expect(steps.value == ["request-a", "request-b", "rawResponse-b", "rawResponse-a"])
    }

    @Test
    func emptyChainReturnsInputUnchanged() async throws {
        let chain = InterceptorChain<any UnaryInterceptor>([])
        let request = try await chain.executeRequest(Self.makeRequest())
        #expect(request.message.payload.data == Self.payload)
    }

    // MARK: - Bridging to closure-based implementations

    /// The load-bearing test for the whole back-mapping design. The `async` spellings are defaulted
    /// in terms of the closure-based ones, which are in turn defaulted to pass values through. An
    /// interceptor implementing neither must therefore terminate at that pass-through. If someone
    /// ever defaults the closure-based spellings in terms of the `async` ones, the two defaults
    /// call each other forever - this test hangs rather than failing, which is the intended signal.
    @Test
    func interceptorImplementingNeitherSpellingTerminates() async throws {
        let chain = InterceptorChain<any UnaryInterceptor>([InertInterceptor()])
        let request = try await chain.executeRequest(Self.makeRequest())
        #expect(request.message.payload.data == Self.payload)
    }

    @Test
    func closureBasedInterceptorIsInvokedThroughTheAsyncSpelling() async throws {
        let chain = InterceptorChain<any UnaryInterceptor>([
            HeaderAddingInterceptor(name: "x-first"),
            HeaderAddingInterceptor(name: "x-second"),
        ])

        let request = try await chain.executeRequest(Self.makeRequest())

        #expect(request.headers["x-first"] == ["set"])
        #expect(request.headers["x-second"] == ["set"])
    }

    @Test
    func closureBasedInterceptorInvokingProceedTwiceIsIgnored() async throws {
        let chain = InterceptorChain<any UnaryInterceptor>([DoubleProceedInterceptor()])

        // Resuming a continuation twice traps, so reaching the assertion at all is the assertion.
        let request = try await chain.executeRequest(Self.makeRequest())

        #expect(request.headers["x-double"] == ["1"])
    }

    @Test
    func closureBasedInterceptorFailureIsThrown() async {
        let chain = InterceptorChain<any UnaryInterceptor>([
            FailingInterceptor(),
            TrackingInterceptor(id: "unreached", steps: Locked([String]())),
        ])

        await #expect(throws: ConnectError.self) {
            _ = try await chain.executeRequest(Self.makeRequest())
        }
    }

    @Test
    func failingInterceptorShortCircuitsTheRestOfTheChain() async {
        let steps = Locked([String]())
        let chain = InterceptorChain<any UnaryInterceptor>([
            FailingInterceptor(),
            TrackingInterceptor(id: "unreached", steps: steps),
        ])

        _ = try? await chain.executeRequest(Self.makeRequest())

        #expect(steps.value.isEmpty)
    }

    // MARK: - Native async conformers

    @Test
    func nativeAsyncInterceptorIsUsedInsteadOfTheBridge() async throws {
        let chain = InterceptorChain<any UnaryInterceptor>([NativeAsyncInterceptor()])
        let request = try await chain.executeRequest(Self.makeRequest())
        #expect(request.headers["x-native"] == ["set"])
    }

    // MARK: - Private

    private static let payload = Data(repeating: 42, count: 4)

    private static func makeRequest() -> HTTPRequest<TestMessage> {
        return HTTPRequest(
            url: URL(string: "https://connectrpc.com/test")!,
            headers: [:],
            message: TestMessage.with { $0.payload.data = Self.payload },
            method: .post,
            trailers: nil,
            idempotencyLevel: .unknown
        )
    }

    private static func makeResponse() -> HTTPResponse {
        return HTTPResponse(
            code: .ok, headers: [:], message: nil, trailers: [:], error: nil, tracingInfo: nil
        )
    }
}

// MARK: - Test interceptors

/// Records the order in which the chain invokes it, using the closure-based spellings.
private final class TrackingInterceptor: UnaryInterceptor {
    private let id: String
    private let steps: Locked<[String]>

    init(id: String, steps: Locked<[String]>) {
        self.id = id
        self.steps = steps
    }

    @Sendable
    func handleUnaryRequest<Message: ProtobufMessage>(
        _ request: HTTPRequest<Message>,
        proceed: @escaping @Sendable (Result<HTTPRequest<Message>, ConnectError>) -> Void
    ) {
        self.steps.perform { $0.append("request-\(self.id)") }
        proceed(.success(request))
    }

    @Sendable
    func handleUnaryRawResponse(
        _ response: HTTPResponse,
        proceed: @escaping @Sendable (HTTPResponse) -> Void
    ) {
        self.steps.perform { $0.append("rawResponse-\(self.id)") }
        proceed(response)
    }
}

/// Implements neither spelling. Must terminate at the pass-through defaults.
private final class InertInterceptor: UnaryInterceptor {}

private final class HeaderAddingInterceptor: UnaryInterceptor {
    private let name: String

    init(name: String) {
        self.name = name
    }

    @Sendable
    func handleUnaryRequest<Message: ProtobufMessage>(
        _ request: HTTPRequest<Message>,
        proceed: @escaping @Sendable (Result<HTTPRequest<Message>, ConnectError>) -> Void
    ) {
        var headers = request.headers
        headers[self.name] = ["set"]
        proceed(.success(HTTPRequest(
            url: request.url,
            headers: headers,
            message: request.message,
            method: request.method,
            trailers: request.trailers,
            idempotencyLevel: request.idempotencyLevel
        )))
    }
}

/// Models a poorly behaved interceptor. Resuming a continuation twice is a crash, so the bridge
/// must claim the right to resume exactly once.
private final class DoubleProceedInterceptor: UnaryInterceptor {
    @Sendable
    func handleUnaryRequest<Message: ProtobufMessage>(
        _ request: HTTPRequest<Message>,
        proceed: @escaping @Sendable (Result<HTTPRequest<Message>, ConnectError>) -> Void
    ) {
        for value in ["1", "2"] {
            var headers = request.headers
            headers["x-double"] = [value]
            proceed(.success(HTTPRequest(
                url: request.url,
                headers: headers,
                message: request.message,
                method: request.method,
                trailers: request.trailers,
                idempotencyLevel: request.idempotencyLevel
            )))
        }
    }
}

private final class FailingInterceptor: UnaryInterceptor {
    @Sendable
    func handleUnaryRequest<Message: ProtobufMessage>(
        _ request: HTTPRequest<Message>,
        proceed: @escaping @Sendable (Result<HTTPRequest<Message>, ConnectError>) -> Void
    ) {
        proceed(.failure(ConnectError(code: .invalidArgument, message: "rejected by interceptor")))
    }
}

/// Implements the `async` spelling directly, skipping the bridge entirely.
private final class NativeAsyncInterceptor: UnaryInterceptor {
    @Sendable
    func handleUnaryRequest<Message: ProtobufMessage>(
        _ request: HTTPRequest<Message>
    ) async throws -> HTTPRequest<Message> {
        var headers = request.headers
        headers["x-native"] = ["set"]
        return HTTPRequest(
            url: request.url,
            headers: headers,
            message: request.message,
            method: request.method,
            trailers: request.trailers,
            idempotencyLevel: request.idempotencyLevel
        )
    }
}
