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

/// Covers the default implementation of `HTTPClientInterface.unary(request:onMetrics:)`, which
/// bridges the closure-based requirement to `async` for clients that do not implement it directly.
struct HTTPClientAsyncBridgeTests {
    @Test
    func forwardsTheResponseFromAClosureBasedClient() async {
        let client = StubHTTPClient(responseCount: 1)
        let response = await client.unary(request: Self.makeRequest(), onMetrics: { _ in })

        #expect(response.code == .ok)
        #expect(response.headers["x-stub"] == ["1"])
    }

    @Test
    func toleratesAClientInvokingOnResponseTwice() async {
        // Resuming a continuation twice traps, so completing at all is the assertion. The stub
        // reports a different header on its second call, pinning that the *first* value wins.
        let client = StubHTTPClient(responseCount: 2)
        let response = await client.unary(request: Self.makeRequest(), onMetrics: { _ in })

        #expect(response.headers["x-stub"] == ["1"])
    }

    @Test
    func cancelingTheTaskCancelsTheUnderlyingRequest() async {
        let client = CancelObservingHTTPClient()
        let task = Task {
            await client.unary(request: Self.makeRequest(), onMetrics: { _ in })
        }

        // Give the bridge a moment to hand out its `Cancelable` before canceling.
        while !client.didStart.value {
            await Task.yield()
        }
        task.cancel()

        let response = await task.value
        #expect(client.didCancel.value)
        #expect(response.code == .canceled)
    }

    private static func makeRequest() -> HTTPRequest<Data?> {
        return HTTPRequest(
            url: URL(string: "https://connectrpc.com/test")!,
            headers: [:],
            message: nil,
            method: .post,
            trailers: nil,
            idempotencyLevel: .unknown
        )
    }
}

// MARK: - Test clients

/// Invokes `onResponse` a fixed number of times, tagging each call so duplicates are detectable.
private final class StubHTTPClient: HTTPClientInterface {
    private let responseCount: Int

    init(responseCount: Int) {
        self.responseCount = responseCount
    }

    @discardableResult
    func unary(
        request: HTTPRequest<Data?>,
        onMetrics: @escaping @Sendable (HTTPMetrics) -> Void,
        onResponse: @escaping @Sendable (HTTPResponse) -> Void
    ) -> Cancelable {
        for invocation in 1...self.responseCount {
            onResponse(HTTPResponse(
                code: .ok,
                headers: ["x-stub": ["\(invocation)"]],
                message: nil,
                trailers: [:],
                error: nil,
                tracingInfo: nil
            ))
        }
        return Cancelable {}
    }

    func stream(
        request: HTTPRequest<Data?>, responseCallbacks: ResponseCallbacks
    ) -> RequestCallbacks<Data> {
        return RequestCallbacks(cancel: {}, sendData: { _ in }, sendClose: {})
    }
}

/// Never responds on its own; responds only when canceled, the way `URLSessionHTTPClient` does.
private final class CancelObservingHTTPClient: HTTPClientInterface {
    let didCancel = Locked(false)
    let didStart = Locked(false)

    @discardableResult
    func unary(
        request: HTTPRequest<Data?>,
        onMetrics: @escaping @Sendable (HTTPMetrics) -> Void,
        onResponse: @escaping @Sendable (HTTPResponse) -> Void
    ) -> Cancelable {
        self.didStart.value = true
        return Cancelable { [didCancel] in
            didCancel.value = true
            onResponse(HTTPResponse(
                code: .canceled,
                headers: [:],
                message: nil,
                trailers: [:],
                error: ConnectError.canceled(),
                tracingInfo: nil
            ))
        }
    }

    func stream(
        request: HTTPRequest<Data?>, responseCallbacks: ResponseCallbacks
    ) -> RequestCallbacks<Data> {
        return RequestCallbacks(cancel: {}, sendData: { _ in }, sendClose: {})
    }
}
