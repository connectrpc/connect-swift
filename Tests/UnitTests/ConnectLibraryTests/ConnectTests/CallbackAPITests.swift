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

import Connect
import Foundation
import Testing

/// Drives the callback API through generated callback methods against the local conformance
/// reference server. Serialized for the same reason as `InterceptorIntegrationTests`.
@Suite(.serialized, .timeLimit(.minutes(1)))
struct CallbackAPITests {
    // Unary tests wait on an `AsyncStream` rather than a continuation, so the time limit can end
    // a test whose completion is never called.
    private typealias UnaryResponse = ResponseMessage<Connectrpc_Conformance_V1_UnaryResponse>

    @Test
    func unaryDeliversTheResponseToItsCompletion() async throws {
        let (responses, continuation) = AsyncStream.makeStream(of: UnaryResponse.self)
        let client = self.makeClient()
        client.unary(
            request: .with { request in
                request.responseDefinition = .with { $0.responseData = Data([1, 2, 3]) }
            },
            completion: { continuation.yield($0) }
        )
        let response = try #require(await responses.first { _ in true })
        #expect(response.message?.payload.data == Data([1, 2, 3]))
    }

    @Test
    func cancelingAUnaryCallCompletesItAsCanceled() async throws {
        let (responses, continuation) = AsyncStream.makeStream(of: UnaryResponse.self)
        let client = self.makeClient()
        let cancelable = client.unary(
            request: .with { request in
                request.responseDefinition = .with { $0.responseDelayMs = 30_000 }
            },
            completion: { continuation.yield($0) }
        )
        cancelable.cancel()
        let response = try #require(await responses.first { _ in true })
        #expect(response.code == .canceled)
    }

    @Test
    func serverOnlyStreamDeliversResultsInOrder() async {
        let (results, continuation) = AsyncStream.makeStream(of: String.self)
        let client = self.makeClient()
        let stream = client.serverStream { result in
            Self.record(result, { $0.payload.data }, into: continuation)
        }
        stream.send(
            .with { request in
                request.responseDefinition = .with { $0.responseData = [Data([1]), Data([2])] }
            })
        #expect(
            await Self.collect(results) == ["headers", "message [1]", "message [2]", "complete ok"]
        )
    }

    @Test
    func bidirectionalStreamSendsEachMessageAndCloses() async {
        let (results, continuation) = AsyncStream.makeStream(of: String.self)
        let client = self.makeClient()
        let stream = client.bidiStream { result in
            // The response echoes every request the server read, so the second send's
            // `requestData` is recorded after the response's own data.
            Self.record(
                result,
                { response in
                    let requests = response.payload.requestInfo.requests.compactMap {
                        try? Connectrpc_Conformance_V1_BidiStreamRequest(unpackingAny: $0)
                    }
                    return response.payload.data + requests.flatMap(\.requestData)
                },
                into: continuation
            )
        }
        stream
            .send(
                .with { request in
                    request.responseDefinition = .with { $0.responseData = [Data([1])] }
                }
            )
            .send(.with { $0.requestData = Data([9]) })
            .close()
        // The half-duplex reference server answers only after it has read the whole request.
        #expect(await Self.collect(results) == ["headers", "message [1, 9]", "complete ok"])
    }

    @Test
    func clientOnlyStreamClosesAndReceivesOneResponse() async throws {
        let (results, continuation) = AsyncStream.makeStream(of: String.self)
        let client = self.makeClient()
        let stream = client.clientStream { result in
            Self.record(result, { $0.payload.data }, into: continuation)
        }
        try stream.send(
            .with { request in
                request.responseDefinition = .with { $0.responseData = Data([7]) }
            })
        stream.closeAndReceive()
        #expect(await Self.collect(results) == ["headers", "message [7]", "complete ok"])
    }

    @Test
    func cancelingAStreamCompletesItAsCanceled() async {
        let (results, continuation) = AsyncStream.makeStream(of: String.self)
        let client = self.makeClient()
        let stream = client.serverStream { result in
            Self.record(result, { $0.payload.data }, into: continuation)
        }
        stream.send(
            .with { request in
                request.responseDefinition = .with { definition in
                    definition.responseData = [Data([1])]
                    definition.responseDelayMs = 30_000
                }
            })
        stream.cancel()
        #expect(await Self.collect(results).last == "complete canceled")
    }

    // MARK: - Private

    private static func record<Output>(
        _ result: StreamResult<Output>,
        _ data: (Output) -> Data,
        into continuation: AsyncStream<String>.Continuation
    ) {
        switch result {
        case .headers:
            continuation.yield("headers")
        case .message(let message):
            continuation.yield("message \(Array(data(message)))")
        case .complete(let code, _, _):
            continuation.yield("complete \(code)")
            continuation.finish()
        }
    }

    private static func collect(_ results: AsyncStream<String>) async -> [String] {
        var collected = [String]()
        for await result in results {
            collected.append(result)
        }
        return collected
    }

    private func makeClient() -> Connectrpc_Conformance_V1_ConformanceServiceClient {
        return Connectrpc_Conformance_V1_ConformanceServiceClient(
            client: ProtocolClient(
                httpClient: URLSessionHTTPClient(),
                config: ProtocolClientConfig(host: "http://localhost:52107")
            )
        )
    }
}
