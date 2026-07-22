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

struct URLSessionStreamTests {
    /// `URLSession` requests a body stream via `urlSession(_:task:needNewBodyStream:)` both for the
    /// initial send and when it resends a request after a recoverable error. A streamed request
    /// body cannot be replayed, and returning the same already-opened stream on a resend crashes
    /// CFNetwork. The stream must therefore be vended only once.
    @available(iOS 13, *)
    @Test
    func vendsRequestBodyStreamOnlyOnce() {
        let stream = URLSessionStream(
            request: URLRequest(url: URL(string: "https://connectrpc.com")!),
            session: URLSession(configuration: .ephemeral),
            responseCallbacks: ResponseCallbacks(
                receiveResponseHeaders: { _ in },
                receiveResponseData: { _ in },
                receiveResponseMetrics: { _ in },
                receiveClose: { _, _, _ in }
            )
        )
        defer { stream.cancel() }

        #expect(stream.requestBodyStream != nil, "The initial body stream should be vended.")
        #expect(
            stream.requestBodyStream == nil,
            "A resend must not reuse the already-opened body stream."
        )
    }

    /// A second `needNewBodyStream` cancels the task because the bound body cannot be replayed.
    /// That cancelation must surface as `.unavailable` (retriable connection failure), not
    /// `.canceled`, and `receiveClose` must fire exactly once.
    @available(iOS 13, *)
    @Test
    func resendCancelationIsRemappedToUnavailableExactlyOnce() async {
        await confirmation("receiveClose", expectedCount: 1) { confirm in
            let stream = URLSessionStream(
                request: URLRequest(url: URL(string: "https://connectrpc.com")!),
                session: URLSession(configuration: .ephemeral),
                responseCallbacks: ResponseCallbacks(
                    receiveResponseHeaders: { _ in },
                    receiveResponseData: { _ in },
                    receiveResponseMetrics: { _ in },
                    receiveClose: { code, _, error in
                        #expect(code == .unavailable)
                        let connectError = error as? ConnectError
                        #expect(
                            connectError?.message ==
                            "connection was reset and the streamed request body cannot be replayed"
                        )
                        confirm()
                    }
                )
            )
            defer { stream.cancel() }

            #expect(stream.requestBodyStream != nil)
            #expect(stream.requestBodyStream == nil)

            // Simulate the cancelation error URLSession delivers after `task.cancel()` from the
            // resend path. `URLSessionStream` is not the session delegate in this unit test, so
            // the callback is invoked directly.
            stream.handleCompletion(
                error: NSError(
                    domain: NSURLErrorDomain,
                    code: URLError.cancelled.rawValue,
                    userInfo: [NSLocalizedDescriptionKey: "cancelled"]
                )
            )
            // Duplicate completion must be suppressed by `closedByServer`.
            stream.handleCompletion(error: nil)
        }
    }
}
