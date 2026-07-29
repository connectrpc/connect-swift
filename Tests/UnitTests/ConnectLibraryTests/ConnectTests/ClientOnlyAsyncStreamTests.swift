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

/// These tests compose a real `BidirectionalAsyncStream`, so they also cover its result
/// delivery, ordering and sending. Only its termination handling is tested separately, in
/// `BidirectionalAsyncStreamTests`.
///
/// The time limit exists because these tests drain a stream: a regression that stops the stream
/// from finishing would otherwise hang the whole test run instead of failing it.
@Suite(.timeLimit(.minutes(1)))
struct ClientOnlyAsyncStreamTests {
    private typealias Empty = Google_Protobuf_Empty

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

    /// A client-only stream expects exactly one response message. Any other count collapses the
    /// whole result set into a single error, which is only satisfiable if results were buffered -
    /// forwarding them as they arrived would have already delivered the headers.
    @Test(arguments: [
        (0, "unary stream has no messages"),
        (2, "unary stream has multiple messages"),
    ])
    func collapsesToAnErrorWhenMessageCountIsNotOne(
        messageCount: Int, expectedMessage: String
    ) async {
        let results = await self.resultsFromServer { stream in
            stream.handleResultFromServer(.headers([:]))
            for _ in 0..<messageCount {
                stream.handleResultFromServer(.message(Empty()))
            }
            stream.handleResultFromServer(.complete(code: .ok, error: nil, trailers: nil))
        }

        #expect(results.count == 1)
        guard case .complete(let code, let error, _) = results.first else {
            Issue.record("Expected a single completion result.")
            return
        }
        #expect(code == .internalError)
        #expect((error as? ConnectError)?.code == .unimplemented)
        #expect((error as? ConnectError)?.message == expectedMessage)
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

    /// These three were inherited before this type moved to composition and are now hand-written
    /// forwards, so the routing is what needs pinning. Asserting the call sequence catches a
    /// swapped forward - `closeAndReceive()` routed to `cancel()` - that per-call counts would
    /// report far less clearly.
    @Test
    func routesSendCloseAndCancelToTheUnderlyingStream() throws {
        let calls = Locked([String]())
        let bidirectional = BidirectionalAsyncStream<Empty, Empty>()
        let clientOnly = ClientOnlyAsyncStream(bidirectionalStream: bidirectional)
        bidirectional.configureForSending(with: RequestCallbacks<Empty>(
            cancel: { calls.perform { $0.append("cancel") } },
            sendData: { _ in calls.perform { $0.append("send") } },
            sendClose: { calls.perform { $0.append("close") } }
        ))

        try clientOnly.send(Empty())
        clientOnly.closeAndReceive()
        clientOnly.cancel()

        #expect(calls.value == ["send", "close", "cancel"])
    }

    @Test
    func sendThrowsWhenTheStreamIsNotConfiguredForSending() {
        let bidirectional = BidirectionalAsyncStream<Empty, Empty>()
        let clientOnly = ClientOnlyAsyncStream(bidirectionalStream: bidirectional)

        #expect(throws: (any Error).self) {
            try clientOnly.send(Empty())
        }
    }

    /// Drives a client-only stream with the given server results and drains everything the
    /// consumer actually observes.
    private func resultsFromServer(
        _ handleResults: (ClientOnlyAsyncStream<Empty, Empty>) -> Void
    ) async -> [StreamResult<Empty>] {
        let bidirectional = BidirectionalAsyncStream<Empty, Empty>()
        let clientOnly = ClientOnlyAsyncStream(bidirectionalStream: bidirectional)
        bidirectional.configureForSending(with: RequestCallbacks<Empty>(
            cancel: {}, sendData: { _ in }, sendClose: {}
        ))

        handleResults(clientOnly)

        var results = [StreamResult<Empty>]()
        for await result in clientOnly.results() {
            results.append(result)
        }
        return results
    }
}
