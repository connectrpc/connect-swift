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

/// Exercises `ProtocolClient.createRequestCallbacks`'s two async pumps end-to-end against a fake
/// transport, with no sleeps and no live networking - the fake and the result collector are both
/// `AsyncStream`-backed so every assertion awaits a specific, ordered event instead of guessing at
/// timing. Nothing here duplicates `InterceptorIntegrationTests` (which pins interceptor ordering
/// against a live server) or `BidirectionalAsyncStreamTests`/`ClientOnlyAsyncStreamTests` (which
/// cover the consumer-facing stream wrapper types in isolation).
@Suite(.timeLimit(.minutes(1)))
struct StreamSpineTests {
    // MARK: - Envelope re-framing

    @Test
    func envelopeSplitAcrossTwoChunksYieldsOneMessage() async throws {
        let transport = FakeStreamHTTPClient()
        let client = Self.makeClient(httpClient: transport)
        let collector = ResultCollector<TestMessage>()
        let stream: any BidirectionalStreamInterface<TestMessage> = client.bidirectionalStream(
            path: "/test", headers: [:], onResult: collector.onResult
        )
        _ = stream

        var events = transport.events.makeAsyncIterator()
        guard case .started(let responseCallbacks) = await events.next() else {
            Issue.record("Expected the transport to start")
            return
        }

        let expectedPayload = Data([1, 2, 3])
        let framed = try Self.envelope(for: .with { $0.payload.data = expectedPayload })
        let splitPoint = framed.count - 2
        responseCallbacks.receiveResponseData(framed.prefix(splitPoint))
        responseCallbacks.receiveResponseData(Data(framed.suffix(from: splitPoint)))
        responseCallbacks.receiveClose(.ok, [:], nil)

        var results = collector.results.makeAsyncIterator()
        guard case .message(let message) = await results.next() else {
            Issue.record("Expected the message once both chunks arrived")
            return
        }
        #expect(message.payload.data == expectedPayload)

        guard case .complete = await results.next() else {
            Issue.record("Expected completion immediately after the message")
            return
        }
    }

    @Test
    func twoEnvelopesInOneChunkArriveInOrderWithDifferentSizes() async throws {
        let transport = FakeStreamHTTPClient()
        let client = Self.makeClient(httpClient: transport)
        let collector = ResultCollector<TestMessage>()
        let stream: any BidirectionalStreamInterface<TestMessage> = client.bidirectionalStream(
            path: "/test", headers: [:], onResult: collector.onResult
        )
        _ = stream

        var events = transport.events.makeAsyncIterator()
        guard case .started(let responseCallbacks) = await events.next() else {
            Issue.record("Expected the transport to start")
            return
        }

        let small = Data([9])
        let large = Data(repeating: 7, count: 300)
        let framedSmall = try Self.envelope(for: .with { $0.payload.data = small })
        let framedLarge = try Self.envelope(for: .with { $0.payload.data = large })

        // `Envelope.messageLength(forPackedData:)` reads absolute indices 1...4 of whatever
        // buffer it is given. If the re-framing loop kept a slice instead of re-basing into fresh
        // `Data` after consuming the first envelope, this second, differently-sized envelope
        // would read the wrong length.
        responseCallbacks.receiveResponseData(framedSmall + framedLarge)
        responseCallbacks.receiveClose(.ok, [:], nil)

        var results = collector.results.makeAsyncIterator()
        guard case .message(let firstMessage) = await results.next() else {
            Issue.record("Expected the small message first")
            return
        }
        #expect(firstMessage.payload.data == small)

        guard case .message(let secondMessage) = await results.next() else {
            Issue.record("Expected the large message second")
            return
        }
        #expect(secondMessage.payload.data == large)

        guard case .complete = await results.next() else {
            Issue.record("Expected completion after both messages")
            return
        }
    }

    @Test
    func chunkShorterThanThePrefixIsBufferedUntilMoreArrives() async throws {
        let transport = FakeStreamHTTPClient()
        let client = Self.makeClient(httpClient: transport)
        let collector = ResultCollector<TestMessage>()
        let stream: any BidirectionalStreamInterface<TestMessage> = client.bidirectionalStream(
            path: "/test", headers: [:], onResult: collector.onResult
        )
        _ = stream

        var events = transport.events.makeAsyncIterator()
        guard case .started(let responseCallbacks) = await events.next() else {
            Issue.record("Expected the transport to start")
            return
        }

        let expectedPayload = Data([42, 42])
        let framed = try Self.envelope(for: .with { $0.payload.data = expectedPayload })
        #expect(framed.count > 5) // Sanity: the split below must land inside the 5-byte prefix.

        responseCallbacks.receiveResponseData(framed.prefix(3))
        responseCallbacks.receiveResponseData(Data(framed.suffix(from: 3)))
        responseCallbacks.receiveClose(.ok, [:], nil)

        var results = collector.results.makeAsyncIterator()
        guard case .message(let message) = await results.next() else {
            Issue.record("Expected the message once the full prefix and payload arrived")
            return
        }
        #expect(message.payload.data == expectedPayload)

        guard case .complete = await results.next() else {
            Issue.record("Expected completion after the message")
            return
        }
    }

    @Test
    func threeEnvelopesAcrossFourRaggedChunksArriveInOrder() async throws {
        let transport = FakeStreamHTTPClient()
        let client = Self.makeClient(httpClient: transport)
        let collector = ResultCollector<TestMessage>()
        let stream: any BidirectionalStreamInterface<TestMessage> = client.bidirectionalStream(
            path: "/test", headers: [:], onResult: collector.onResult
        )
        _ = stream

        var events = transport.events.makeAsyncIterator()
        guard case .started(let responseCallbacks) = await events.next() else {
            Issue.record("Expected the transport to start")
            return
        }

        let payloads = [Data([1]), Data(repeating: 2, count: 50), Data([3, 3, 3])]
        let framed = try payloads.map { payload in
            try Self.envelope(for: TestMessage.with { $0.payload.data = payload })
        }
        let combined = framed.reduce(Data(), +)

        var messageRanges: [Range<Int>] = []
        var cumulativeLength = 0
        for chunk in framed {
            messageRanges.append(cumulativeLength..<(cumulativeLength + chunk.count))
            cumulativeLength += chunk.count
        }

        // Deliberately ragged, computed from the codec's actual output rather than assumed byte
        // counts: the midpoint of message 1, and two points inside message 2's span, so no split
        // lands on a message boundary regardless of how the codec encodes each payload.
        let split0 = (messageRanges[0].lowerBound + messageRanges[0].upperBound) / 2
        let range1 = messageRanges[1]
        let span1 = range1.upperBound - range1.lowerBound
        let splitPoints = [
            split0, range1.lowerBound + span1 / 3, range1.lowerBound + (span1 * 2) / 3,
        ]
        #expect(splitPoints == splitPoints.sorted())
        #expect(Set(splitPoints).count == splitPoints.count)

        var chunks: [Data] = []
        var previousPoint = 0
        for point in splitPoints {
            chunks.append(combined.subdata(in: previousPoint..<point))
            previousPoint = point
        }
        chunks.append(combined.subdata(in: previousPoint..<combined.count))
        #expect(chunks.count == 4)

        for chunk in chunks {
            responseCallbacks.receiveResponseData(chunk)
        }
        responseCallbacks.receiveClose(.ok, [:], nil)

        var results = collector.results.makeAsyncIterator()
        for payload in payloads {
            guard case .message(let message) = await results.next() else {
                Issue.record("Expected a message with payload \(payload)")
                return
            }
            #expect(message.payload.data == payload)
        }
        guard case .complete = await results.next() else {
            Issue.record("Expected completion after all three messages")
            return
        }
    }

    // MARK: - Outbound buffering before the transport exists

    @Test
    func sendsBeforeStartAreBufferedAndDeliveredInOrder() async throws {
        let gate = Gate()
        let transport = FakeStreamHTTPClient()
        let client = Self.makeClient(
            httpClient: transport, interceptors: [.init { _ in GatedStartInterceptor(gate: gate) }]
        )
        let collector = ResultCollector<TestMessage>()
        let stream: any BidirectionalStreamInterface<TestMessage> = client.bidirectionalStream(
            path: "/test", headers: [:], onResult: collector.onResult
        )

        let payloads = [Data([1]), Data([2]), Data([3])]
        for payload in payloads {
            stream.send(.with { $0.payload.data = payload })
        }
        gate.open()

        var events = transport.events.makeAsyncIterator()
        guard case .started = await events.next() else {
            Issue.record("Expected the transport to start before any send reaches it")
            return
        }

        for payload in payloads {
            guard case .data(let framed) = await events.next() else {
                Issue.record("Expected a send for payload \(payload)")
                return
            }
            let (_, unpacked) = try Envelope.unpackMessage(framed, compressionPool: nil)
            let message: TestMessage = try JSONCodec().deserialize(source: unpacked)
            #expect(message.payload.data == payload)
        }
    }

    @Test
    func closeBeforeStartIsBufferedAndAppliedAfterTheTransportExists() async throws {
        let gate = Gate()
        let transport = FakeStreamHTTPClient()
        let client = Self.makeClient(
            httpClient: transport, interceptors: [.init { _ in GatedStartInterceptor(gate: gate) }]
        )
        let collector = ResultCollector<TestMessage>()
        let stream: any BidirectionalStreamInterface<TestMessage> = client.bidirectionalStream(
            path: "/test", headers: [:], onResult: collector.onResult
        )

        stream.close()
        gate.open()

        var events = transport.events.makeAsyncIterator()
        guard case .started = await events.next() else {
            Issue.record("Expected the transport to start")
            return
        }
        guard case .close = await events.next() else {
            Issue.record("Expected sendClose after the transport started")
            return
        }
    }

    @Test
    func cancelBeforeStartIsBufferedAndAppliedAfterTheTransportExists() async throws {
        let gate = Gate()
        let transport = FakeStreamHTTPClient()
        let client = Self.makeClient(
            httpClient: transport, interceptors: [.init { _ in GatedStartInterceptor(gate: gate) }]
        )
        let collector = ResultCollector<TestMessage>()
        let stream: any BidirectionalStreamInterface<TestMessage> = client.bidirectionalStream(
            path: "/test", headers: [:], onResult: collector.onResult
        )

        stream.cancel()
        gate.open()

        var events = transport.events.makeAsyncIterator()
        guard case .started = await events.next() else {
            Issue.record("Expected the transport to start")
            return
        }
        guard case .cancel = await events.next() else {
            Issue.record("Expected cancel after the transport started")
            return
        }
    }

    // MARK: - The hasCompleted latch

    /// `ConnectInterceptor.handleStreamRawResult` converts an end-stream envelope into `.complete`
    /// *inside the chain*, and the transport then also fires `receiveClose`. This duplicate
    /// originates downstream of the events `AsyncStream.finish()` can absorb, so the pump keeps its
    /// own `hasCompleted` latch. `EndStreamMarkingInterceptor` mimics that conversion without
    /// depending on the real Connect end-stream JSON format.
    @Test
    func duplicateCompletionsAreLatchedAfterAnInterceptorConvertsAMessageToComplete() async throws {
        let transport = FakeStreamHTTPClient()
        let client = Self.makeClient(
            httpClient: transport, interceptors: [.init { _ in EndStreamMarkingInterceptor() }]
        )
        let collector = ResultCollector<TestMessage>()
        let stream: any BidirectionalStreamInterface<TestMessage> = client.bidirectionalStream(
            path: "/test", headers: [:], onResult: collector.onResult
        )
        _ = stream

        var events = transport.events.makeAsyncIterator()
        guard case .started(let responseCallbacks) = await events.next() else {
            Issue.record("Expected the transport to start")
            return
        }

        // The designated end-stream marker, converted to `.complete` by
        // `EndStreamMarkingInterceptor`.
        responseCallbacks.receiveResponseData(Envelope.packMessage(Data([0xFF]), using: nil))
        // A probe sent before the transport's own close (`receiveClose` finishes the inbound
        // continuation, so anything sent after it would be silently dropped rather than exercise
        // the latch): if the duplicate `.complete` had been delivered instead of latched, it would
        // arrive here instead of the probe, since delivery is ordered.
        let probePayload = Data([9, 9, 9])
        responseCallbacks.receiveResponseData(
            try Self.envelope(for: .with { $0.payload.data = probePayload })
        )
        // The transport also reports its own close, exactly as a real Connect-protocol stream does.
        responseCallbacks.receiveClose(.ok, [:], nil)

        var results = collector.results.makeAsyncIterator()
        guard case .complete(let code, _, _) = await results.next() else {
            Issue.record("Expected the end-stream marker to produce a completion")
            return
        }
        #expect(code == .ok)

        guard case .message(let probe) = await results.next() else {
            Issue.record("Expected the probe message, not a duplicate completion")
            return
        }
        #expect(probe.payload.data == probePayload)
    }

    // MARK: - Silent drops preserved from the closure-based implementation

    @Test
    func deserializeFailureDropsTheMessageAndThePumpSurvives() async throws {
        let transport = FakeStreamHTTPClient()
        let client = Self.makeClient(httpClient: transport, codec: FailableCodec())
        let collector = ResultCollector<TestMessage>()
        let stream: any BidirectionalStreamInterface<TestMessage> = client.bidirectionalStream(
            path: "/test", headers: [:], onResult: collector.onResult
        )
        _ = stream

        var events = transport.events.makeAsyncIterator()
        guard case .started(let responseCallbacks) = await events.next() else {
            Issue.record("Expected the transport to start")
            return
        }

        let poisoned = TestMessage.with { $0.payload.data = FailableCodec.poisonPayload }
        responseCallbacks.receiveResponseData(try Self.envelope(for: poisoned))
        responseCallbacks.receiveClose(.ok, [:], nil)

        // The poisoned message fails `toTyped`'s deserialize and is silently dropped - the next
        // result is the close, not an error standing in for the dropped message.
        var results = collector.results.makeAsyncIterator()
        guard case .complete(let code, _, _) = await results.next() else {
            Issue.record(
                "Expected the deserialize failure to be dropped, delivering only the close"
            )
            return
        }
        #expect(code == .ok)
    }

    @Test
    func serializeFailureDropsTheOutboundMessageAndThePumpSurvives() async throws {
        let transport = FakeStreamHTTPClient()
        let client = Self.makeClient(httpClient: transport, codec: FailableCodec())
        let collector = ResultCollector<TestMessage>()
        let stream: any BidirectionalStreamInterface<TestMessage> = client.bidirectionalStream(
            path: "/test", headers: [:], onResult: collector.onResult
        )

        stream.send(.with { $0.payload.data = FailableCodec.poisonPayload })
        let validPayload = Data([7, 7, 7])
        stream.send(.with { $0.payload.data = validPayload })

        var events = transport.events.makeAsyncIterator()
        guard case .started = await events.next() else {
            Issue.record("Expected the transport to start")
            return
        }

        // The poisoned send never reaches the transport - the next outbound event is the valid
        // send, not an error frame standing in for the dropped one.
        guard case .data(let framed) = await events.next() else {
            Issue.record("Expected the valid send to survive the poisoned one being dropped")
            return
        }
        let (_, unpacked) = try Envelope.unpackMessage(framed, compressionPool: nil)
        let message: TestMessage = try JSONCodec().deserialize(source: unpacked)
        #expect(message.payload.data == validPayload)
    }

    // MARK: - Start failure

    @Test
    func startFailureDeliversOneCompletionWithoutCreatingTheTransport() async throws {
        let transport = FakeStreamHTTPClient()
        let client = Self.makeClient(
            httpClient: transport, interceptors: [.init { _ in FailingStartInterceptor() }]
        )
        let collector = ResultCollector<TestMessage>()
        let stream: any BidirectionalStreamInterface<TestMessage> = client.bidirectionalStream(
            path: "/test", headers: [:], onResult: collector.onResult
        )
        _ = stream

        var results = collector.results.makeAsyncIterator()
        guard case .complete(let code, let error, _) = await results.next() else {
            Issue.record("Expected the start failure to produce a completion")
            return
        }
        #expect(code == .aborted)
        #expect(error != nil)
        // The success and failure branches of the start chain are mutually exclusive within the
        // same sequential task; having already observed the failure's completion, this flag can
        // only still be `false`.
        #expect(!transport.didCreateStream.value)
    }

    // MARK: - Ordering under a slow interceptor

    @Test
    func slowRawResultInterceptorStillDeliversResultsInOrder() async throws {
        let transport = FakeStreamHTTPClient()
        let client = Self.makeClient(
            httpClient: transport, interceptors: [.init { _ in DelayingRawResultInterceptor() }]
        )
        let collector = ResultCollector<TestMessage>()
        let stream: any BidirectionalStreamInterface<TestMessage> = client.bidirectionalStream(
            path: "/test", headers: [:], onResult: collector.onResult
        )
        _ = stream

        var events = transport.events.makeAsyncIterator()
        guard case .started(let responseCallbacks) = await events.next() else {
            Issue.record("Expected the transport to start")
            return
        }

        let first = Data([1])
        let second = Data([2])
        responseCallbacks.receiveResponseData(
            try Self.envelope(for: .with { $0.payload.data = first })
        )
        responseCallbacks.receiveResponseData(
            try Self.envelope(for: .with { $0.payload.data = second })
        )
        responseCallbacks.receiveClose(.ok, [:], nil)

        var results = collector.results.makeAsyncIterator()
        guard case .message(let firstResult) = await results.next() else {
            Issue.record("Expected the first message")
            return
        }
        #expect(firstResult.payload.data == first)

        guard case .message(let secondResult) = await results.next() else {
            Issue.record("Expected the second message")
            return
        }
        #expect(secondResult.payload.data == second)
    }

    // MARK: - Termination ordering

    /// `BidirectionalAsyncStream.handleResultFromServer` finishes its own continuation upon
    /// `.complete`, which synchronously fires `onTermination` and calls `sendClose()` on the
    /// `RequestCallbacks` this pump returned - all before the inbound pump gets a chance to finish
    /// its own outbound continuation. Both must therefore observe the same `.close`, not a dropped
    /// one racing a finished stream.
    @Test
    func serverCompletionClosesTheOutboundTransportBeforeFinishingBuffersEverything() async throws {
        let transport = FakeStreamHTTPClient()
        let client = Self.makeClient(httpClient: transport)
        let stream: any BidirectionalAsyncStreamInterface<TestMessage, TestMessage> =
            client.bidirectionalStream(path: "/test", headers: [:])

        var events = transport.events.makeAsyncIterator()
        guard case .started(let responseCallbacks) = await events.next() else {
            Issue.record("Expected the transport to start")
            return
        }

        responseCallbacks.receiveClose(.ok, [:], nil)

        for await result in stream.results() {
            if case .complete = result {
                break
            }
        }

        guard case .close = await events.next() else {
            Issue.record("Expected sendClose to reach the transport after the server completed")
            return
        }
    }

    // MARK: - Private

    private static func makeClient(
        httpClient: FakeStreamHTTPClient,
        interceptors: [InterceptorFactory] = [],
        codec: Codec = JSONCodec()
    ) -> ProtocolClient {
        let config = ProtocolClientConfig(
            host: "https://connectrpc.com",
            networkProtocol: .custom(
                name: "envelope-only", protocolInterceptor: .init { _ in EnvelopeOnlyInterceptor() }
            ),
            codec: codec,
            interceptors: interceptors
        )
        return ProtocolClient(httpClient: httpClient, config: config)
    }

    private static func envelope(for message: TestMessage) throws -> Data {
        return Envelope.packMessage(try JSONCodec().serialize(message: message), using: nil)
    }
}

// MARK: - Fake transport

private enum TransportEvent: Sendable {
    case started(ResponseCallbacks)
    case data(Data)
    case close
    case cancel
}

/// A stream transport whose `stream(request:responseCallbacks:)` hands back its `ResponseCallbacks`
/// (wrapped as a `.started` event) and reports every outbound action as an event too, so tests can
/// drive inbound results and observe outbound sends deterministically via `events`, with no sleeps
/// and no live networking.
private final class FakeStreamHTTPClient: HTTPClientInterface, @unchecked Sendable {
    let events: AsyncStream<TransportEvent>
    private let continuation: AsyncStream<TransportEvent>.Continuation
    /// Set synchronously at the top of `stream(request:responseCallbacks:)`, so it is only ever
    /// `true` if that method was actually reached.
    let didCreateStream = Locked(false)

    init() {
        (self.events, self.continuation) = AsyncStream.makeStream()
    }

    @discardableResult
    func unary(
        request: HTTPRequest<Data?>,
        onMetrics: @escaping @Sendable (HTTPMetrics) -> Void,
        onResponse: @escaping @Sendable (HTTPResponse) -> Void
    ) -> Cancelable {
        fatalError("StreamSpineTests does not exercise the unary path")
    }

    func stream(
        request: HTTPRequest<Data?>, responseCallbacks: ResponseCallbacks
    ) -> RequestCallbacks<Data> {
        self.didCreateStream.value = true
        let continuation = self.continuation
        continuation.yield(.started(responseCallbacks))
        return RequestCallbacks<Data>(
            cancel: { continuation.yield(.cancel) },
            sendData: { continuation.yield(.data($0)) },
            sendClose: { continuation.yield(.close) }
        )
    }
}

// MARK: - Result collection

/// Collects results delivered via a stream's `onResult` closure into an `AsyncStream`, so tests can
/// await them in order with no sleeps and no polling.
private final class ResultCollector<Output: ProtobufMessage>: @unchecked Sendable {
    let results: AsyncStream<StreamResult<Output>>
    private let continuation: AsyncStream<StreamResult<Output>>.Continuation

    init() {
        (self.results, self.continuation) = AsyncStream.makeStream()
    }

    func onResult(_ result: StreamResult<Output>) {
        self.continuation.yield(result)
    }
}

// MARK: - Gating

/// A one-shot async gate. `wait()` suspends until `open()` is called, letting a test control
/// exactly when a suspended interceptor resumes without any sleeps.
private final class Gate: @unchecked Sendable {
    private let stream: AsyncStream<Void>
    private let continuation: AsyncStream<Void>.Continuation

    init() {
        (self.stream, self.continuation) = AsyncStream.makeStream()
    }

    func wait() async {
        for await _ in self.stream {
            return
        }
    }

    func open() {
        self.continuation.yield(())
        self.continuation.finish()
    }
}

private final class GatedStartInterceptor: StreamInterceptor {
    private let gate: Gate

    init(gate: Gate) {
        self.gate = gate
    }

    @Sendable
    func handleStreamStart(_ request: HTTPRequest<Void>) async throws -> HTTPRequest<Void> {
        await self.gate.wait()
        return request
    }
}

// MARK: - Test interceptors

private final class FailingStartInterceptor: StreamInterceptor {
    @Sendable
    func handleStreamStart(
        _ request: HTTPRequest<Void>,
        proceed: @escaping @Sendable (Result<HTTPRequest<Void>, ConnectError>) -> Void
    ) {
        proceed(.failure(ConnectError(code: .aborted, message: "rejected by interceptor")))
    }
}

/// Packs outbound payloads and unpacks inbound ones, without any of `ConnectInterceptor`'s other
/// protocol-specific behavior (content-type headers, end-stream detection, compression). Isolates
/// `StreamSpineTests` from changes to the real protocol interceptors.
private final class EnvelopeOnlyInterceptor: StreamInterceptor {
    @Sendable
    func handleStreamRawInput(_ input: Data, proceed: @escaping @Sendable (Data) -> Void) {
        proceed(Envelope.packMessage(input, using: nil))
    }

    @Sendable
    func handleStreamRawResult(
        _ result: StreamResult<Data>,
        proceed: @escaping @Sendable (StreamResult<Data>) -> Void
    ) {
        guard case .message(let data) = result else {
            proceed(result)
            return
        }
        guard let unpacked = try? Envelope.unpackMessage(data, compressionPool: nil) else {
            return // Matches a real protocol interceptor's shape: drop on unpack failure.
        }
        proceed(.message(unpacked.unpacked))
    }
}

/// Mimics `ConnectInterceptor.handleStreamRawResult` converting a designated end-stream `.message`
/// into `.complete` inside the chain, without depending on the real Connect end-stream JSON format.
private final class EndStreamMarkingInterceptor: StreamInterceptor {
    @Sendable
    func handleStreamRawResult(
        _ result: StreamResult<Data>,
        proceed: @escaping @Sendable (StreamResult<Data>) -> Void
    ) {
        if case .message(let data) = result, data == Data([0xFF]) {
            proceed(.complete(code: .ok, error: nil, trailers: [:]))
        } else {
            proceed(result)
        }
    }
}

/// Suspends partway through processing the first `.message` it sees, using `Task.yield()` rather
/// than a real-time sleep, to prove that a slow interceptor cannot reorder results delivered by the
/// single-consumer inbound pump.
private final class DelayingRawResultInterceptor: StreamInterceptor {
    private let hasDelayed = Locked(false)

    @Sendable
    func handleStreamRawResult(_ result: StreamResult<Data>) async -> StreamResult<Data> {
        let shouldDelay = self.hasDelayed.perform { hasDelayed -> Bool in
            guard !hasDelayed, case .message = result else {
                return false
            }
            hasDelayed = true
            return true
        }
        if shouldDelay {
            for _ in 0..<3 {
                await Task.yield()
            }
        }
        return result
    }
}

// MARK: - Failable codec

/// Wraps `JSONCodec`, failing to serialize or deserialize one designated payload so tests can pin
/// the silent-drop behaviors without any timing-dependent flag toggling - the failure is purely a
/// function of the message content, not of when the test flips a switch.
private final class FailableCodec: Codec {
    static let poisonPayload = Data([0xDE, 0xAD])

    private let wrapped = JSONCodec()

    func name() -> String {
        return self.wrapped.name()
    }

    func serialize<Input: ProtobufMessage>(message: Input) throws -> Data {
        if let message = message as? TestMessage, message.payload.data == Self.poisonPayload {
            throw ConnectError(code: .internalError, message: "intentional test failure")
        }
        return try self.wrapped.serialize(message: message)
    }

    func deterministicallySerialize<Input: ProtobufMessage>(message: Input) throws -> Data {
        return try self.wrapped.deterministicallySerialize(message: message)
    }

    func deserialize<Output: ProtobufMessage>(source: Data) throws -> Output {
        let decoded: Output = try self.wrapped.deserialize(source: source)
        if let decoded = decoded as? TestMessage, decoded.payload.data == Self.poisonPayload {
            throw ConnectError(code: .internalError, message: "intentional test failure")
        }
        return decoded
    }
}
