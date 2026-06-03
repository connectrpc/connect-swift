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
import XCTest

final class URLSessionStreamTests: XCTestCase {
    /// `URLSession` requests a body stream via `urlSession(_:task:needNewBodyStream:)` both for the
    /// initial send and when it resends a request after a recoverable error. A streamed request
    /// body cannot be replayed, and returning the same already-opened stream on a resend crashes
    /// CFNetwork. The stream must therefore be vended only once.
    func testVendsRequestBodyStreamOnlyOnce() {
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

        XCTAssertNotNil(stream.requestBodyStream, "The initial body stream should be vended.")
        XCTAssertNil(
            stream.requestBodyStream,
            "A resend must not reuse the already-opened body stream."
        )
    }
}
