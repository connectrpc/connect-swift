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

struct TimeoutTests {
    @available(iOS 13, *)
    @Test
    func unaryRequestTimesOut() async {
        let client = self.makeClient()
        let response = await client.unary(request: .with { request in
            request.responseDefinition = .with { _ in }
        })

        #expect(response.code == .deadlineExceeded)
        #expect(response.error?.code == .deadlineExceeded)
        #expect(response.error?.message == "request exceeded allowed timeout")
    }

    @available(iOS 13, *)
    @Test
    func streamRequestTimesOut() async throws {
        let client = self.makeClient()
        let stream = client.serverStream()
        try stream.send(.with { request in
            request.responseDefinition = .with { _ in }
        })

        var completion: StreamResult<Connectrpc_Conformance_V1_ServerStreamResponse>?
        for await result in stream.results() {
            completion = result
        }

        guard case .complete(let code, let error, _) = completion else {
            Issue.record("Expected stream to complete with a timeout error.")
            return
        }

        #expect(code == .deadlineExceeded)
        #expect((error as? ConnectError)?.code == .deadlineExceeded)
        #expect((error as? ConnectError)?.message == "request exceeded allowed timeout")
    }

    private func makeClient() -> Connectrpc_Conformance_V1_ConformanceServiceClient {
        let config = ProtocolClientConfig(
            host: "http://localhost",
            timeout: 0.01
        )
        let protocolClient = ProtocolClient(httpClient: TimeoutHTTPClient(), config: config)
        return Connectrpc_Conformance_V1_ConformanceServiceClient(client: protocolClient)
    }
}

// Safety: @unchecked Sendable — test double confined to a single test invocation.
private final class TimeoutHTTPClient: HTTPClientInterface, @unchecked Sendable {
    @discardableResult
    func unary(
        request: HTTPRequest<Data?>,
        onMetrics: @escaping @Sendable (HTTPMetrics) -> Void,
        onResponse: @escaping @Sendable (HTTPResponse) -> Void
    ) -> Cancelable {
        let didRespond = Locked(false)
        return Cancelable {
            let shouldRespond = didRespond.perform { didRespond in
                if didRespond {
                    return false
                }
                didRespond = true
                return true
            }
            guard shouldRespond else {
                return
            }
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
        request: HTTPRequest<Data?>,
        responseCallbacks: ResponseCallbacks
    ) -> RequestCallbacks<Data> {
        let didClose = Locked(false)
        return RequestCallbacks(
            cancel: {
                let shouldClose = didClose.perform { didClose in
                    if didClose {
                        return false
                    }
                    didClose = true
                    return true
                }
                guard shouldClose else {
                    return
                }
                responseCallbacks.receiveClose(.canceled, [:], ConnectError.canceled())
            },
            sendData: { _ in },
            sendClose: { }
        )
    }
}
