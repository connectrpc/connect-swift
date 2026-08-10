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

struct AsyncStreamInterceptorTests {
    // MARK: - Ordering

    @Test
    func requestPathIsFIFOAndResponsePathIsLIFO() async throws {
        let steps = Locked([String]())
        let chain = InterceptorChain<any StreamInterceptor>([
            TrackingInterceptor(id: "a", steps: steps),
            TrackingInterceptor(id: "b", steps: steps),
        ])

        _ = try await chain.executeStart(Self.makeRequest())
        _ = await chain.executeInput(TestMessage())
        _ = await chain.executeRawInput(Data())
        _ = await chain.executeRawResult(.message(Data()))
        _ = await chain.executeResult(StreamResult<TestMessage>.message(TestMessage()))

        #expect(steps.value == [
            "start-a", "start-b",
            "input-a", "input-b",
            "rawInput-a", "rawInput-b",
            "rawResult-b", "rawResult-a",
            "result-b", "result-a",
        ])
    }

    @Test
    func metricsPathIsLIFO() async {
        let steps = Locked([String]())
        let chain = InterceptorChain<any StreamInterceptor>([
            TrackingInterceptor(id: "a", steps: steps),
            TrackingInterceptor(id: "b", steps: steps),
        ])

        _ = await chain.executeMetrics(HTTPMetrics(taskMetrics: nil))

        #expect(steps.value == ["metrics-b", "metrics-a"])
    }

    @Test
    func emptyChainReturnsInputUnchanged() async throws {
        let chain = InterceptorChain<any StreamInterceptor>([])
        let request = try await chain.executeStart(Self.makeRequest())
        #expect(request.headers["x-original"] == ["set"])
    }

    // MARK: - Bridging to closure-based implementations

    /// The load-bearing test for the whole back-mapping design, mirroring
    /// `AsyncUnaryInterceptorTests.interceptorImplementingNeitherSpellingTerminates`. The `async`
    /// spellings are defaulted in terms of the closure-based ones, which are in turn defaulted to
    /// pass values through. An interceptor implementing neither must therefore terminate at that
    /// pass-through. If someone ever defaults the closure-based spellings in terms of the `async`
    /// ones, the two defaults call each other forever - this test hangs rather than failing, which
    /// is the intended signal.
    @Test
    func interceptorImplementingNeitherSpellingTerminates() async throws {
        let chain = InterceptorChain<any StreamInterceptor>([InertStreamInterceptor()])
        let request = try await chain.executeStart(Self.makeRequest())
        #expect(request.headers["x-original"] == ["set"])

        let input = await chain.executeInput(TestMessage())
        #expect(input == TestMessage())

        let rawInput = await chain.executeRawInput(Data([1, 2, 3]))
        #expect(rawInput == Data([1, 2, 3]))

        let rawResult = await chain.executeRawResult(.message(Data([4, 5, 6])))
        #expect(rawResult == .message(Data([4, 5, 6])))

        let result = await chain.executeResult(StreamResult<TestMessage>.message(TestMessage()))
        #expect(result == .message(TestMessage()))
    }

    @Test
    func closureBasedInterceptorIsInvokedThroughTheAsyncSpelling() async throws {
        let chain = InterceptorChain<any StreamInterceptor>([
            HeaderAddingInterceptor(name: "x-first"),
            HeaderAddingInterceptor(name: "x-second"),
        ])

        let request = try await chain.executeStart(Self.makeRequest())

        #expect(request.headers["x-first"] == ["set"])
        #expect(request.headers["x-second"] == ["set"])
    }

    @Test
    func closureBasedInterceptorInvokingProceedTwiceIsIgnored() async throws {
        let chain = InterceptorChain<any StreamInterceptor>([DoubleProceedInterceptor()])

        // Resuming a continuation twice traps, so reaching the assertion at all is the assertion.
        let result = await chain.executeRawResult(.message(Data([0])))

        #expect(result == .message(Data([1])))
    }

    @Test
    func closureBasedInterceptorFailureIsThrown() async {
        let chain = InterceptorChain<any StreamInterceptor>([
            FailingInterceptor(),
            TrackingInterceptor(id: "unreached", steps: Locked([String]())),
        ])

        await #expect(throws: ConnectError.self) {
            _ = try await chain.executeStart(Self.makeRequest())
        }
    }

    @Test
    func startFailureIsThrownAndShortCircuitsTheChain() async {
        let steps = Locked([String]())
        let chain = InterceptorChain<any StreamInterceptor>([
            FailingInterceptor(),
            TrackingInterceptor(id: "unreached", steps: steps),
        ])

        _ = try? await chain.executeStart(Self.makeRequest())

        #expect(steps.value.isEmpty)
    }

    // MARK: - Native async conformers

    @Test
    func nativeAsyncInterceptorIsUsedInsteadOfTheBridge() async throws {
        let chain = InterceptorChain<any StreamInterceptor>([NativeAsyncInterceptor()])
        let request = try await chain.executeStart(Self.makeRequest())
        #expect(request.headers["x-native"] == ["set"])
    }

    // MARK: - Private

    private static func makeRequest() -> HTTPRequest<Void> {
        return HTTPRequest(
            url: URL(string: "https://connectrpc.com/test")!,
            headers: ["x-original": ["set"]],
            message: (),
            method: .post,
            trailers: nil,
            idempotencyLevel: .unknown
        )
    }
}

// MARK: - Test interceptors

/// Records the order in which the chain invokes it, using the closure-based spellings.
private final class TrackingInterceptor: StreamInterceptor {
    private let id: String
    private let steps: Locked<[String]>

    init(id: String, steps: Locked<[String]>) {
        self.id = id
        self.steps = steps
    }

    @Sendable
    func handleStreamStart(
        _ request: HTTPRequest<Void>,
        proceed: @escaping @Sendable (Result<HTTPRequest<Void>, ConnectError>) -> Void
    ) {
        self.steps.perform { $0.append("start-\(self.id)") }
        proceed(.success(request))
    }

    @Sendable
    func handleStreamInput<Message: ProtobufMessage>(
        _ input: Message,
        proceed: @escaping @Sendable (Message) -> Void
    ) {
        self.steps.perform { $0.append("input-\(self.id)") }
        proceed(input)
    }

    @Sendable
    func handleStreamRawInput(
        _ input: Data,
        proceed: @escaping @Sendable (Data) -> Void
    ) {
        self.steps.perform { $0.append("rawInput-\(self.id)") }
        proceed(input)
    }

    @Sendable
    func handleStreamRawResult(
        _ result: StreamResult<Data>,
        proceed: @escaping @Sendable (StreamResult<Data>) -> Void
    ) {
        self.steps.perform { $0.append("rawResult-\(self.id)") }
        proceed(result)
    }

    @Sendable
    func handleStreamResult<Message: ProtobufMessage>(
        _ result: StreamResult<Message>,
        proceed: @escaping @Sendable (StreamResult<Message>) -> Void
    ) {
        self.steps.perform { $0.append("result-\(self.id)") }
        proceed(result)
    }

    @Sendable
    func handleResponseMetrics(
        _ metrics: HTTPMetrics,
        proceed: @escaping @Sendable (HTTPMetrics) -> Void
    ) {
        self.steps.perform { $0.append("metrics-\(self.id)") }
        proceed(metrics)
    }
}

/// Implements neither spelling. Must terminate at the pass-through defaults.
private final class InertStreamInterceptor: StreamInterceptor {}

private final class HeaderAddingInterceptor: StreamInterceptor {
    private let name: String

    init(name: String) {
        self.name = name
    }

    @Sendable
    func handleStreamStart(
        _ request: HTTPRequest<Void>,
        proceed: @escaping @Sendable (Result<HTTPRequest<Void>, ConnectError>) -> Void
    ) {
        var headers = request.headers
        headers[self.name] = ["set"]
        proceed(.success(HTTPRequest(
            url: request.url,
            headers: headers,
            message: (),
            method: request.method,
            trailers: request.trailers,
            idempotencyLevel: request.idempotencyLevel
        )))
    }
}

/// Models a poorly behaved interceptor. Resuming a continuation twice is a crash, so the bridge
/// must claim the right to resume exactly once.
private final class DoubleProceedInterceptor: StreamInterceptor {
    @Sendable
    func handleStreamRawResult(
        _ result: StreamResult<Data>,
        proceed: @escaping @Sendable (StreamResult<Data>) -> Void
    ) {
        proceed(.message(Data([1])))
        proceed(.message(Data([2])))
    }
}

private final class FailingInterceptor: StreamInterceptor {
    @Sendable
    func handleStreamStart(
        _ request: HTTPRequest<Void>,
        proceed: @escaping @Sendable (Result<HTTPRequest<Void>, ConnectError>) -> Void
    ) {
        proceed(.failure(ConnectError(code: .aborted, message: "rejected by interceptor")))
    }
}

/// Implements the `async` spelling directly, skipping the bridge entirely.
private final class NativeAsyncInterceptor: StreamInterceptor {
    @Sendable
    func handleStreamStart(_ request: HTTPRequest<Void>) async throws -> HTTPRequest<Void> {
        var headers = request.headers
        headers["x-native"] = ["set"]
        return HTTPRequest(
            url: request.url,
            headers: headers,
            message: (),
            method: request.method,
            trailers: request.trailers,
            idempotencyLevel: request.idempotencyLevel
        )
    }
}
