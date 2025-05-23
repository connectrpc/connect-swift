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
import ConnectMocks
import Foundation
import SwiftProtobuf
import Testing

/// Test suite that validates the behavior of generated mock classes.
struct ConnectMocksTests {
    // MARK: - Unary

    @available(iOS 13, *)
    @Test("ConnectMocks provides mock unary client that supports callback-based testing")
    func mockUnaryCallbacks() {
        let client = Connectrpc_Conformance_V1_ConformanceServiceClientMock()
        client.mockUnary = { request in
            #expect(request.hasResponseDefinition)
            return ResponseMessage(result: .success(.with { $0.payload.data = Data([0x0]) }))
        }

        let receivedMessage = Locked<Connectrpc_Conformance_V1_UnaryResponse?>(nil)
        client.unary(request: .with { $0.responseDefinition = .init() }) { response in
            receivedMessage.value = response.message
        }
        #expect(receivedMessage.value?.payload.data.count == 1)
    }

    @available(iOS 13, *)
    @Test("ConnectMocks provides mock unary client that supports async/await testing")
    func mockUnaryAsyncAwait() async {
        let client = Connectrpc_Conformance_V1_ConformanceServiceClientMock()
        client.mockAsyncUnary = { request in
            #expect(request.hasResponseDefinition)
            return ResponseMessage(result: .success(.with { $0.payload.data = Data([0x0]) }))
        }

        let response = await client.unary(request: .with { $0.responseDefinition = .init() })
        #expect(response.message?.payload.data.count == 1)
    }

    // MARK: - Bidirectional stream

    @available(iOS 13, *)
    @Test("ConnectMocks provides mock bidirectional stream client that supports callback-based testing")
    func mockBidirectionalStreamCallbacks() {
        let client = Connectrpc_Conformance_V1_ConformanceServiceClientMock()
        let expectedInputs: [Connectrpc_Conformance_V1_BidiStreamRequest] = [
            .with { $0.responseDefinition.responseData = [Data(repeating: 0, count: 123)] },
            .with { $0.responseDefinition.responseData = [Data(repeating: 0, count: 456)] },
        ]
        let expectedResults: [StreamResult<Connectrpc_Conformance_V1_BidiStreamResponse>] =
        [
            .headers(["x-header": ["123"]]),
            .message(.with { $0.payload.data = Data(repeating: 0, count: 123) }),
            .message(.with { $0.payload.data = Data(repeating: 0, count: 456) }),
            .complete(code: .ok, error: nil, trailers: nil),
        ]
        #expect(!client.mockBidiStream.isClosed)

        var sentInputs = [Connectrpc_Conformance_V1_BidiStreamRequest]()
        var closeCalled = false
        client.mockBidiStream.onSend = { sentInputs.append($0) }
        client.mockBidiStream.onClose = { closeCalled = true }
        client.mockBidiStream.outputs = Array(expectedResults)

        let receivedResults = Locked(
            [StreamResult<Connectrpc_Conformance_V1_BidiStreamResponse>]()
        )
        let stream = client.bidiStream { result in
            receivedResults.perform { $0.append(result) }
        }
        stream.send(expectedInputs[0])
        stream.send(expectedInputs[1])
        stream.close()

        #expect(sentInputs == expectedInputs)
        #expect(client.mockBidiStream.inputs == expectedInputs)
        #expect(receivedResults.value == expectedResults)
        #expect(closeCalled)
        #expect(client.mockBidiStream.isClosed)
    }

    @available(iOS 13, *)
    @Test("ConnectMocks provides mock bidirectional stream client that supports async/await testing")
    func mockBidirectionalStreamAsyncAwait() async throws {
        let client = Connectrpc_Conformance_V1_ConformanceServiceClientMock()
        let expectedInputs: [Connectrpc_Conformance_V1_BidiStreamRequest] = [
            .with { $0.responseDefinition.responseData = [Data(repeating: 0, count: 123)] },
            .with { $0.responseDefinition.responseData = [Data(repeating: 0, count: 456)] },
        ]
        var expectedResults: [StreamResult<Connectrpc_Conformance_V1_BidiStreamResponse>] =
        [
            .headers(["x-header": ["123"]]),
            .message(.with { $0.payload.data = Data(repeating: 0, count: 123) }),
            .message(.with { $0.payload.data = Data(repeating: 0, count: 456) }),
            .complete(code: .ok, error: nil, trailers: nil),
        ]
        #expect(!client.mockAsyncBidiStream.isClosed)

        var sentInputs = [Connectrpc_Conformance_V1_BidiStreamRequest]()
        var closeCalled = false
        client.mockAsyncBidiStream.onSend = { sentInputs.append($0) }
        client.mockAsyncBidiStream.onClose = { closeCalled = true }
        client.mockAsyncBidiStream.outputs = Array(expectedResults)

        let stream = client.bidiStream()
        try stream.send(expectedInputs[0])
        try stream.send(expectedInputs[1])
        stream.close()

        for await result in stream.results() {
            #expect(result == expectedResults.removeFirst())
        }

        #expect(sentInputs == expectedInputs)
        #expect(client.mockAsyncBidiStream.inputs == expectedInputs)
        #expect(expectedResults.isEmpty)
        #expect(closeCalled)
        #expect(client.mockAsyncBidiStream.isClosed)
    }

    // MARK: - Server-only stream

    @available(iOS 13, *)
    @Test("ConnectMocks provides mock server stream client that supports callback-based testing")
    func mockServerOnlyStreamCallbacks() {
        let client = Connectrpc_Conformance_V1_ConformanceServiceClientMock()
        let expectedInputs: [Connectrpc_Conformance_V1_ServerStreamRequest] = [
            .with { $0.responseDefinition.responseData = [Data(repeating: 0, count: 123)] },
        ]
        let expectedResults: [StreamResult<Connectrpc_Conformance_V1_ServerStreamResponse>] = [
            .headers(["x-header": ["123"]]),
            .message(.with { $0.payload.data = Data(repeating: 0, count: 123) }),
            .message(.with { $0.payload.data = Data(repeating: 0, count: 456) }),
            .complete(code: .ok, error: nil, trailers: nil),
        ]

        var sentInputs = [Connectrpc_Conformance_V1_ServerStreamRequest]()
        client.mockServerStream.onSend = { sentInputs.append($0) }
        client.mockServerStream.outputs = Array(expectedResults)

        let receivedResults = Locked([
            StreamResult<Connectrpc_Conformance_V1_ServerStreamResponse>
        ]())
        let stream = client.serverStream { result in
            receivedResults.perform { $0.append(result) }
        }
        stream.send(expectedInputs[0])

        #expect(sentInputs == expectedInputs)
        #expect(client.mockServerStream.inputs == expectedInputs)
        #expect(receivedResults.value == expectedResults)
    }

    @available(iOS 13, *)
    @Test("ConnectMocks provides mock server stream client that supports async/await testing")
    func mockServerOnlyStreamAsyncAwait() async throws {
        let client = Connectrpc_Conformance_V1_ConformanceServiceClientMock()
        let expectedInputs: [Connectrpc_Conformance_V1_ServerStreamRequest] = [
            .with { $0.responseDefinition.responseData = [Data(repeating: 0, count: 123)] },
        ]
        var expectedResults: [StreamResult<Connectrpc_Conformance_V1_ServerStreamResponse>] =
        [
            .headers(["x-header": ["123"]]),
            .message(.with { $0.payload.data = Data(repeating: 0, count: 123) }),
            .message(.with { $0.payload.data = Data(repeating: 0, count: 456) }),
            .complete(code: .ok, error: nil, trailers: nil),
        ]

        var sentInputs = [Connectrpc_Conformance_V1_ServerStreamRequest]()
        client.mockAsyncServerStream.onSend = { sentInputs.append($0) }
        client.mockAsyncServerStream.outputs = Array(expectedResults)

        let stream = client.serverStream()
        try stream.send(expectedInputs[0])

        for await result in stream.results() {
            #expect(result == expectedResults.removeFirst())
        }

        #expect(sentInputs == expectedInputs)
        #expect(client.mockAsyncServerStream.inputs == expectedInputs)
        #expect(expectedResults.isEmpty)
    }
}
