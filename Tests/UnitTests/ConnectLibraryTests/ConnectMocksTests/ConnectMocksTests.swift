// Copyright 2022-2024 The Connect Authors
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
import SwiftProtobuf
import XCTest

/// Test suite that validates the behavior of generated mock classes.
@available(iOS 13, *)
final class ConnectMocksTests: XCTestCase {
    // MARK: - Unary

    func testMockUnaryCallbacks() {
        let client = Connectrpc_Conformance_V1_ConformanceServiceClientMock()
        client.mockUnary = { request in
            XCTAssertTrue(request.hasResponseDefinition)
            return ResponseMessage(result: .success(.with { $0.payload.data = Data([0x0]) }))
        }

        let receivedMessage = Locked<Connectrpc_Conformance_V1_UnaryResponse?>(nil)
        client.unary(request: .with { $0.responseDefinition = .init() }) { response in
            receivedMessage.value = response.message
        }
        XCTAssertEqual(receivedMessage.value?.payload.data.count, 1)
    }

    func testMockUnaryAsyncAwait() async {
        let client = Connectrpc_Conformance_V1_ConformanceServiceClientMock()
        client.mockAsyncUnary = { request in
            XCTAssertTrue(request.hasResponseDefinition)
            return ResponseMessage(result: .success(.with { $0.payload.data = Data([0x0]) }))
        }

        let response = await client.unary(request: .with { $0.responseDefinition = .init() })
        XCTAssertEqual(response.message?.payload.data.count, 1)
    }

    // MARK: - Bidirectional stream

    func testMockBidirectionalStreamCallbacks() {
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
        XCTAssertFalse(client.mockBidiStream.isClosed)

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

        XCTAssertEqual(sentInputs, expectedInputs)
        XCTAssertEqual(client.mockBidiStream.inputs, expectedInputs)
        XCTAssertEqual(receivedResults.value, expectedResults)
        XCTAssertTrue(closeCalled)
        XCTAssertTrue(client.mockBidiStream.isClosed)
    }

    func testMockBidirectionalStreamAsyncAwait() async throws {
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
        XCTAssertFalse(client.mockAsyncBidiStream.isClosed)

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
            XCTAssertEqual(result, expectedResults.removeFirst())
        }

        XCTAssertEqual(sentInputs, expectedInputs)
        XCTAssertEqual(client.mockAsyncBidiStream.inputs, expectedInputs)
        XCTAssertTrue(expectedResults.isEmpty)
        XCTAssertTrue(closeCalled)
        XCTAssertTrue(client.mockAsyncBidiStream.isClosed)
    }

    // MARK: - Server-only stream

    func testMockServerOnlyStreamCallbacks() {
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

        XCTAssertEqual(sentInputs, expectedInputs)
        XCTAssertEqual(client.mockServerStream.inputs, expectedInputs)
        XCTAssertEqual(receivedResults.value, expectedResults)
    }

    func testMockServerOnlyStreamAsyncAwait() async throws {
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
            XCTAssertEqual(result, expectedResults.removeFirst())
        }

        XCTAssertEqual(sentInputs, expectedInputs)
        XCTAssertEqual(client.mockAsyncServerStream.inputs, expectedInputs)
        XCTAssertTrue(expectedResults.isEmpty)
    }
}
