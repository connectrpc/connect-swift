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
import SwiftProtobuf
import Testing

struct ClientOnlyAsyncStreamTests {
    private typealias Empty = Google_Protobuf_Empty

    // MARK: - Buffering and validation

    @Test
    func forwardsBufferedResultsInOrderForAWellFormedStream() async {
        let results = await self.resultsFromServer { stream in
            stream.handleResultFromServer(.headers(["a": ["b"]]))
            stream.handleResultFromServer(.message(Empty()))
            stream.handleResultFromServer(.complete(code: .ok, error: nil, trailers: nil))
        }

        #expect(results.count == 3)
        guard case .headers(let headers) = results.first else {
            Issue.record("Expected headers to be received first.")
            return
        }
        #expect(headers == ["a": ["b"]])
        guard case .complete(let code, _, _) = results.last else {
            Issue.record("Expected the stream to end with a completion.")
            return
        }
        #expect(code == .ok)
    }

    /// A client-only stream expects exactly one response message. Zero messages collapses the
    /// whole result set into a single error, which is only possible because results are buffered
    /// rather than forwarded as they arrive - a passthrough implementation would have already
    /// delivered the headers by this point.
    @Test
    func collapsesToAnErrorWhenTheStreamHasNoMessages() async {
        let results = await self.resultsFromServer { stream in
            stream.handleResultFromServer(.headers([:]))
            stream.handleResultFromServer(.complete(code: .ok, error: nil, trailers: nil))
        }

        #expect(results.count == 1)
        guard case .complete(let code, let error, _) = results.first else {
            Issue.record("Expected a single completion result.")
            return
        }
        #expect(code == .internalError)
        #expect((error as? ConnectError)?.code == .unimplemented)
        #expect((error as? ConnectError)?.message == "unary stream has no messages")
    }

    @Test
    func collapsesToAnErrorWhenTheStreamHasMultipleMessages() async {
        let results = await self.resultsFromServer { stream in
            stream.handleResultFromServer(.headers([:]))
            stream.handleResultFromServer(.message(Empty()))
            stream.handleResultFromServer(.message(Empty()))
            stream.handleResultFromServer(.complete(code: .ok, error: nil, trailers: nil))
        }

        #expect(results.count == 1)
        guard case .complete(let code, let error, _) = results.first else {
            Issue.record("Expected a single completion result.")
            return
        }
        #expect(code == .internalError)
        #expect((error as? ConnectError)?.code == .unimplemented)
        #expect((error as? ConnectError)?.message == "unary stream has multiple messages")
    }

    /// When the server itself fails, its error must surface untouched rather than being masked by
    /// the "no messages" validation that a zero-message stream would otherwise trigger.
    @Test
    func passesResultsThroughWhenTheStreamCompletesWithAnError() async {
        let serverError = ConnectError(code: .unavailable, message: "server is down")
        let results = await self.resultsFromServer { stream in
            stream.handleResultFromServer(.headers([:]))
            stream.handleResultFromServer(
                .complete(code: .unavailable, error: serverError, trailers: nil)
            )
        }

        #expect(results.count == 2)
        guard case .complete(let code, let error, _) = results.last else {
            Issue.record("Expected the stream to end with a completion.")
            return
        }
        #expect(code == .unavailable)
        #expect((error as? ConnectError)?.message == "server is down")
    }

    @Test
    func doesNotForwardResultsBeforeTheStreamCompletes() async {
        let bidirectional = BidirectionalAsyncStream<Empty, Empty>()
        let clientOnly = ClientOnlyAsyncStream(bidirectionalStream: bidirectional)
        bidirectional.configureForSending(with: Self.noOpCallbacks())

        clientOnly.handleResultFromServer(.headers([:]))
        clientOnly.handleResultFromServer(.message(Empty()))

        // Nothing has completed the stream, so a consumer must still be waiting. Cancelling it
        // is what makes that assertion terminate rather than hang.
        let received = Locked(0)
        let consumer = Task {
            for await _ in clientOnly.results() {
                received.perform { $0 += 1 }
            }
        }
        consumer.cancel()
        await consumer.value
        #expect(received.value == 0)
    }

    // MARK: - Delegation to the underlying bidirectional stream

    // These assertions are synchronous - each call routes straight through to the request
    // callbacks - so they read the counters directly rather than using `confirmation`.

    @Test
    func closeAndReceiveClosesTheStreamWithoutCancelling() {
        let didClose = Locked(0)
        let didCancel = Locked(0)
        let bidirectional = BidirectionalAsyncStream<Empty, Empty>()
        let clientOnly = ClientOnlyAsyncStream(bidirectionalStream: bidirectional)
        bidirectional.configureForSending(with: RequestCallbacks<Empty>(
            cancel: { didCancel.perform { $0 += 1 } },
            sendData: { _ in },
            sendClose: { didClose.perform { $0 += 1 } }
        ))

        clientOnly.closeAndReceive()

        #expect(didClose.value == 1)
        #expect(didCancel.value == 0)
    }

    @Test
    func cancelCancelsTheStreamWithoutClosing() {
        let didClose = Locked(0)
        let didCancel = Locked(0)
        let bidirectional = BidirectionalAsyncStream<Empty, Empty>()
        let clientOnly = ClientOnlyAsyncStream(bidirectionalStream: bidirectional)
        bidirectional.configureForSending(with: RequestCallbacks<Empty>(
            cancel: { didCancel.perform { $0 += 1 } },
            sendData: { _ in },
            sendClose: { didClose.perform { $0 += 1 } }
        ))

        clientOnly.cancel()

        #expect(didCancel.value == 1)
        #expect(didClose.value == 0)
    }

    @Test
    func sendForwardsMessagesToTheUnderlyingStream() throws {
        let sentMessages = Locked(0)
        let bidirectional = BidirectionalAsyncStream<Empty, Empty>()
        let clientOnly = ClientOnlyAsyncStream(bidirectionalStream: bidirectional)
        bidirectional.configureForSending(with: RequestCallbacks<Empty>(
            cancel: {}, sendData: { _ in sentMessages.perform { $0 += 1 } }, sendClose: {}
        ))

        try clientOnly.send(Empty())
        try clientOnly.send(Empty())

        #expect(sentMessages.value == 2)
    }

    @Test
    func sendThrowsWhenTheStreamIsNotConfiguredForSending() {
        let bidirectional = BidirectionalAsyncStream<Empty, Empty>()
        let clientOnly = ClientOnlyAsyncStream(bidirectionalStream: bidirectional)

        #expect(throws: (any Error).self) {
            try clientOnly.send(Empty())
        }
    }

    // MARK: - Private

    private static func noOpCallbacks() -> RequestCallbacks<Empty> {
        return RequestCallbacks<Empty>(cancel: {}, sendData: { _ in }, sendClose: {})
    }

    /// Drives a client-only stream with the given server results and drains everything the
    /// consumer actually observes.
    private func resultsFromServer(
        _ handleResults: (ClientOnlyAsyncStream<Empty, Empty>) -> Void
    ) async -> [StreamResult<Empty>] {
        let bidirectional = BidirectionalAsyncStream<Empty, Empty>()
        let clientOnly = ClientOnlyAsyncStream(bidirectionalStream: bidirectional)
        bidirectional.configureForSending(with: Self.noOpCallbacks())

        handleResults(clientOnly)

        var results = [StreamResult<Empty>]()
        for await result in clientOnly.results() {
            results.append(result)
        }
        return results
    }
}
