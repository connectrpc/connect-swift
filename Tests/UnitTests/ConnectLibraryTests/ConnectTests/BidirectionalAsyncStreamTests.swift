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

/// Result delivery, ordering and sending are covered by `ClientOnlyAsyncStreamTests`, which
/// composes a real `BidirectionalAsyncStream` and therefore exercises all of it. What only this
/// suite can reach is the termination handler that closes the request when the stream ends.
///
/// The time limit exists because these tests consume a stream: a regression that stops results
/// being delivered would otherwise hang the whole test run instead of failing it.
@Suite(.timeLimit(.minutes(1)))
struct BidirectionalAsyncStreamTests {
    private typealias Empty = Google_Protobuf_Empty

    @Test
    func closesTheRequestWhenTheStreamCompletes() async {
        await confirmation("the request is closed") { closed in
            let stream = BidirectionalAsyncStream<Empty, Empty>()
            stream.configureForSending(with: RequestCallbacks<Empty>(
                cancel: {}, sendData: { _ in }, sendClose: { closed() }
            ))

            stream.handleResultFromServer(.complete(code: .ok, error: nil, trailers: nil))
        }
    }

    /// A stream abandoned without completing must still close the request. This is the only test
    /// that pins the termination handler capturing the callbacks box rather than `self`:
    /// capturing `self` forms a retain cycle, so the instance never deallocates, the handler
    /// never runs, and the request is left open.
    @Test
    func closesTheRequestWhenReleasedWithoutCompleting() async {
        await confirmation("the request is closed") { closed in
            await self.consumeOneResultThenRelease(onClose: closed)
        }
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
