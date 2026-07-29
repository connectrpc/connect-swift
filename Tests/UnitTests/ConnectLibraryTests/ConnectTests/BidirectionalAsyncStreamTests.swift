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

struct BidirectionalAsyncStreamTests {
    private typealias Empty = Google_Protobuf_Empty

    @Test
    func deliversResultsInOrderAndClosesOnComplete() async {
        let didClose = Locked(false)
        let stream = BidirectionalAsyncStream<Empty, Empty>()
        stream.configureForSending(with: RequestCallbacks<Empty>(
            cancel: {}, sendData: { _ in }, sendClose: { didClose.value = true }
        ))

        stream.handleResultFromServer(.headers(["a": ["b"]]))
        stream.handleResultFromServer(.message(Empty()))
        stream.handleResultFromServer(.complete(code: .ok, error: nil, trailers: nil))

        var results = [StreamResult<Empty>]()
        for await result in stream.results() {
            results.append(result)
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

        try? await Task.sleep(nanoseconds: 50_000_000)
        #expect(didClose.value)
    }

    @Test
    func closesUnderlyingStreamWhenConsumingTaskIsCancelled() async {
        let didClose = Locked(false)
        let stream = BidirectionalAsyncStream<Empty, Empty>()
        stream.configureForSending(with: RequestCallbacks<Empty>(
            cancel: {}, sendData: { _ in }, sendClose: { didClose.value = true }
        ))

        let consumer = Task {
            for await _ in stream.results() {}
        }
        try? await Task.sleep(nanoseconds: 50_000_000)
        consumer.cancel()
        await consumer.value

        try? await Task.sleep(nanoseconds: 100_000_000)
        #expect(didClose.value)
    }

    @Test
    func closesUnderlyingStreamWhenReleasedWithoutCompleting() async {
        let didClose = Locked(false)
        await self.consumeOneResultThenRelease(didClose: didClose)

        try? await Task.sleep(nanoseconds: 100_000_000)
        #expect(didClose.value)
    }

    @Test
    func clientOnlyStreamBuffersResultsUntilComplete() async {
        let bidirectional = BidirectionalAsyncStream<Empty, Empty>()
        let clientOnly = ClientOnlyAsyncStream(bidirectionalStream: bidirectional)
        bidirectional.configureForSending(with: RequestCallbacks<Empty>(
            cancel: {}, sendData: { _ in }, sendClose: {}
        ))

        clientOnly.handleResultFromServer(.headers([:]))
        clientOnly.handleResultFromServer(.message(Empty()))
        clientOnly.handleResultFromServer(.complete(code: .ok, error: nil, trailers: nil))

        var results = [StreamResult<Empty>]()
        for await result in clientOnly.results() {
            results.append(result)
        }
        #expect(results.count == 3)
    }

    /// Creates a stream in its own scope, consumes a single result, then returns so that the
    /// stream is released without ever completing.
    private func consumeOneResultThenRelease(didClose: Locked<Bool>) async {
        let stream = BidirectionalAsyncStream<Empty, Empty>()
        stream.configureForSending(with: RequestCallbacks<Empty>(
            cancel: {}, sendData: { _ in }, sendClose: { didClose.value = true }
        ))
        stream.handleResultFromServer(.headers([:]))
        for await _ in stream.results() {
            break
        }
    }
}
