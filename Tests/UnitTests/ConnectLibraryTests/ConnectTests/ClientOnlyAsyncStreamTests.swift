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

/// Composes a real `BidirectionalAsyncStream`, so these cover its delivery and sending too.
///
/// Time-limited so a stream that never finishes fails rather than hangs.
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

    /// Exactly one message is expected; any other count replaces the buffered results with a
    /// single error. Doubles as the buffering check - a passthrough would have delivered headers.
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
