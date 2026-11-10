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

private typealias Request = Connectrpc_Conformance_V1_BidiStreamRequest
private typealias Response = Connectrpc_Conformance_V1_BidiStreamResponse

struct StreamCodecFailureTests {
    @Test
    func deserializeFailureEndsStreamWithError() async throws {
        let transport = RecordingStreamHTTPClient()
        let stream: any BidirectionalAsyncStreamInterface<Request, Response> = Self
            .makeClient(transport: transport, codec: JSONCodec())
            .bidirectionalStream(path: "/test", headers: [:])
        try stream.send(Request())

        let callbacks = try #require(transport.responseCallbacks.value)
        callbacks.receiveResponseHeaders(["content-type": ["application/connect+json"]])
        callbacks.receiveResponseData(Envelope.packMessage(Data("{".utf8), using: nil))
        callbacks.receiveResponseData(
            Envelope.packMessage(try JSONCodec().serialize(message: Response()), using: nil)
        )
        callbacks.receiveClose(.ok, [:], nil)

        var results = [StreamResult<Response>]()
        for await result in stream.results() {
            results.append(result)
        }

        #expect(results.count == 2)
        guard case .headers = results.first else {
            Issue.record("Expected headers first, got \(results)")
            return
        }
        guard case .complete(let code, let error, _) = results.last else {
            Issue.record("Expected the stream to complete, got \(results)")
            return
        }
        #expect(code == .internalError)
        #expect((error as? ConnectError)?.message == "failed to deserialize stream message")
        #expect(transport.cancelCount.value == 1)
    }

    @Test
    func serializeFailureEndsStreamWithError() async throws {
        let transport = RecordingStreamHTTPClient()
        let stream: any BidirectionalAsyncStreamInterface<Request, Response> = Self
            .makeClient(transport: transport, codec: FailingSerializeCodec())
            .bidirectionalStream(path: "/test", headers: [:])
        try stream.send(Request())
        let callbacks = try #require(transport.responseCallbacks.value)
        callbacks.receiveClose(.ok, [:], nil)

        var results = [StreamResult<Response>]()
        for await result in stream.results() {
            results.append(result)
        }

        #expect(results.count == 1)
        guard case .complete(let code, let error, _) = results.first else {
            Issue.record("Expected the stream to complete, got \(results)")
            return
        }
        #expect(code == .internalError)
        #expect((error as? ConnectError)?.message == "failed to serialize stream message")
        #expect(transport.sentDataCount.value == 0)
        #expect(transport.cancelCount.value == 1)
    }

    @Test
    func unarySerializeFailureReturnsInternalError() async {
        let transport = RecordingStreamHTTPClient()
        let response: ResponseMessage<Response> = await Self
            .makeClient(transport: transport, codec: FailingSerializeCodec())
            .unary(path: "/test", idempotencyLevel: .unknown, request: Request(), headers: [:])

        #expect(response.code == .internalError)
        #expect(response.error?.code == .internalError)
        #expect(response.error?.message == "request serialization failed")
    }

    @Test
    func unaryDeserializeFailureReturnsInternalError() async {
        let transport = RecordingStreamHTTPClient(unaryResponseBody: Data("{".utf8))
        let response: ResponseMessage<Response> = await Self
            .makeClient(transport: transport, codec: JSONCodec())
            .unary(path: "/test", idempotencyLevel: .unknown, request: Request(), headers: [:])

        #expect(response.code == .internalError)
        #expect(response.error?.code == .internalError)
        #expect(response.error?.message == "response deserialization failed")
    }

    private static func makeClient(
        transport: RecordingStreamHTTPClient, codec: Codec
    ) -> ProtocolClient {
        return ProtocolClient(
            httpClient: transport,
            config: ProtocolClientConfig(host: "http://localhost", codec: codec)
        )
    }
}

/// Fails every `serialize` call and otherwise behaves like `JSONCodec`.
private struct FailingSerializeCodec: Codec {
    struct SerializeError: Error {}

    func name() -> String {
        return "json"
    }

    func serialize<Input: ProtobufMessage>(message: Input) throws -> Data {
        throw SerializeError()
    }

    func deterministicallySerialize<Input: ProtobufMessage>(message: Input) throws -> Data {
        throw SerializeError()
    }

    func deserialize<Output: ProtobufMessage>(source: Data) throws -> Output {
        return try JSONCodec().deserialize(source: source)
    }
}

/// Answers unary requests with `unaryResponseBody`, exposes the response callbacks of the last
/// stream it started, and counts what the client sends to it. Canceling closes the stream with
/// `.canceled`, like the real clients.
private final class RecordingStreamHTTPClient: HTTPClientInterface, Sendable {
    let unaryResponseBody: Data?
    let responseCallbacks = Locked<ResponseCallbacks?>(nil)
    let cancelCount = Locked(0)
    let sentDataCount = Locked(0)

    init(unaryResponseBody: Data? = nil) {
        self.unaryResponseBody = unaryResponseBody
    }

    func unary(
        request: HTTPRequest<Data?>,
        onMetrics: @escaping @Sendable (HTTPMetrics) -> Void,
        onResponse: @escaping @Sendable (HTTPResponse) -> Void
    ) -> Cancelable {
        guard let body = self.unaryResponseBody else {
            Issue.record("Unexpected unary request")
            return Cancelable {}
        }
        onResponse(HTTPResponse(
            code: .ok,
            headers: ["content-type": ["application/json"]],
            message: body,
            trailers: [:],
            error: nil,
            tracingInfo: nil
        ))
        return Cancelable {}
    }

    func stream(
        request: HTTPRequest<Data?>,
        responseCallbacks: ResponseCallbacks
    ) -> RequestCallbacks<Data> {
        self.responseCallbacks.value = responseCallbacks
        return RequestCallbacks(
            cancel: {
                self.cancelCount.perform { $0 += 1 }
                responseCallbacks.receiveClose(.canceled, [:], ConnectError.canceled())
            },
            sendData: { _ in self.sentDataCount.perform { $0 += 1 } },
            sendClose: {}
        )
    }
}
