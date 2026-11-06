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

    @Test
    func unaryTransportErrorAfterDeadlineTimesOut() async {
        let client = self.makeClient(httpClient: TransportErrorHTTPClient(
            code: .unknown, delayNanoseconds: 100_000_000
        ))
        let response = await client.unary(request: .init())

        #expect(response.code == .deadlineExceeded)
        #expect(response.error?.code == .deadlineExceeded)
    }

    @Test
    func streamTransportErrorAfterDeadlineTimesOut() async throws {
        let client = self.makeClient(httpClient: TransportErrorHTTPClient(
            code: .unknown, delayNanoseconds: 100_000_000
        ))

        let code = try await self.serverStreamCompletionCode(using: client)

        #expect(code == .deadlineExceeded)
    }

    @Test
    func unaryTransportErrorBeforeDeadlineKeepsItsCode() async {
        let client = self.makeClient(
            httpClient: TransportErrorHTTPClient(code: .unavailable, delayNanoseconds: 0),
            timeout: 60
        )
        let response = await client.unary(request: .init())

        #expect(response.code == .unavailable)
    }

    @Test
    func streamTransportErrorBeforeDeadlineKeepsItsCode() async throws {
        let client = self.makeClient(
            httpClient: TransportErrorHTTPClient(code: .unavailable, delayNanoseconds: 0),
            timeout: 60
        )

        let code = try await self.serverStreamCompletionCode(using: client)

        #expect(code == .unavailable)
    }

    private func serverStreamCompletionCode(
        using client: Connectrpc_Conformance_V1_ConformanceServiceClient
    ) async throws -> Code? {
        let stream = client.serverStream()
        try stream.send(.init())
        for await result in stream.results() {
            if case .complete(let code, _, _) = result {
                return code
            }
        }
        return nil
    }

    private func makeClient(
        httpClient: HTTPClientInterface = TimeoutHTTPClient(),
        timeout: TimeInterval = 0.01
    ) -> Connectrpc_Conformance_V1_ConformanceServiceClient {
        let config = ProtocolClientConfig(
            host: "http://localhost",
            timeout: timeout
        )
        let protocolClient = ProtocolClient(httpClient: httpClient, config: config)
        return Connectrpc_Conformance_V1_ConformanceServiceClient(client: protocolClient)
    }
}

// Ignores cancelation and fails with a transport error after a delay, like a server that
// resets the request when it enforces the deadline before the client's timer fires.
private final class TransportErrorHTTPClient: HTTPClientInterface, Sendable {
    private let code: Code
    private let delayNanoseconds: UInt64

    init(code: Code, delayNanoseconds: UInt64) {
        self.code = code
        self.delayNanoseconds = delayNanoseconds
    }

    @discardableResult
    func unary(
        request: HTTPRequest<Data?>,
        onMetrics: @escaping @Sendable (HTTPMetrics) -> Void,
        onResponse: @escaping @Sendable (HTTPResponse) -> Void
    ) -> Cancelable {
        Task { [code, delayNanoseconds] in
            try? await Task.sleep(nanoseconds: delayNanoseconds)
            onResponse(HTTPResponse(
                code: code,
                headers: [:],
                message: nil,
                trailers: [:],
                error: TransportError(),
                tracingInfo: nil
            ))
        }
        return Cancelable {}
    }

    func stream(
        request: HTTPRequest<Data?>,
        responseCallbacks: ResponseCallbacks
    ) -> RequestCallbacks<Data> {
        Task { [code, delayNanoseconds] in
            try? await Task.sleep(nanoseconds: delayNanoseconds)
            responseCallbacks.receiveClose(code, [:], TransportError())
        }
        return RequestCallbacks(cancel: {}, sendData: { _ in }, sendClose: {})
    }
}

private struct TransportError: Error {}

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
