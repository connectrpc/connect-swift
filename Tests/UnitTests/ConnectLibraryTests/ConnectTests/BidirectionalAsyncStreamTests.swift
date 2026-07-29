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
        let results = await confirmation("the underlying stream is closed") { closed in
            let stream = BidirectionalAsyncStream<Empty, Empty>()
            stream.configureForSending(with: RequestCallbacks<Empty>(
                cancel: {}, sendData: { _ in }, sendClose: { closed() }
            ))

            stream.handleResultFromServer(.headers(["a": ["b"]]))
            stream.handleResultFromServer(.message(Empty()))
            stream.handleResultFromServer(.complete(code: .ok, error: nil, trailers: nil))

            var results = [StreamResult<Empty>]()
            for await result in stream.results() {
                results.append(result)
            }
            return results
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

    @Test
    func closesUnderlyingStreamWhenConsumingTaskIsCancelled() async {
        await confirmation("the underlying stream is closed") { closed in
            let stream = BidirectionalAsyncStream<Empty, Empty>()
            stream.configureForSending(with: RequestCallbacks<Empty>(
                cancel: {}, sendData: { _ in }, sendClose: { closed() }
            ))

            // Route one result through the consumer and wait for it to come back out. This
            // proves the consuming task is running and iterating before it gets cancelled,
            // without having to sleep and hope.
            let (consuming, isConsuming) = AsyncStream.makeStream(of: Void.self)
            let consumer = Task {
                for await _ in stream.results() {
                    isConsuming.yield()
                }
            }
            stream.handleResultFromServer(.headers([:]))
            for await _ in consuming {
                break
            }

            consumer.cancel()
            await consumer.value
        }
    }

    @Test
    func closesUnderlyingStreamWhenReleasedWithoutCompleting() async {
        await confirmation("the underlying stream is closed") { closed in
            await self.consumeOneResultThenRelease(onClose: closed)
        }
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
    /// stream is released without ever completing. The release - and therefore the close - is
    /// complete by the time this function returns.
    private func consumeOneResultThenRelease(onClose: Confirmation) async {
        let stream = BidirectionalAsyncStream<Empty, Empty>()
        stream.configureForSending(with: RequestCallbacks<Empty>(
            cancel: {}, sendData: { _ in }, sendClose: { onClose() }
        ))
        stream.handleResultFromServer(.headers([:]))
        for await _ in stream.results() {
            break
        }
    }
}
