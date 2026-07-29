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

/// Delivery and sending are covered by `ClientOnlyAsyncStreamTests`, which composes this type;
/// what remains here is termination.
///
/// Time-limited so a stalled stream fails rather than hangs.
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

    @Test
    func closesTheRequestWhenReleasedWithoutCompleting() async {
        await confirmation("the request is closed") { closed in
            await self.consumeOneResultThenRelease(onClose: closed)
        }
    }

    /// Separate function so the stream is deterministically released when it returns.
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
