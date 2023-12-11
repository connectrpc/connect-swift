// Copyright 2022-2023 The Connect Authors
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
@available(iOS 13.0, watchOS 6.0, *)
final class ConnectMocksTests: XCTestCase {
    // MARK: - Unary

    func testMockUnaryCallbacks() {
        let client = Connectrpc_Conformance_V1_TestServiceClientMock()
        client.mockUnaryCall = { request in
            XCTAssertTrue(request.fillUsername)
            return ResponseMessage(result: .success(.with { $0.hostname = "pong" }))
        }

        let receivedMessage = Locked<Connectrpc_Conformance_V1_SimpleResponse?>(nil)
        client.unaryCall(request: .with { $0.fillUsername = true }) { response in
            receivedMessage.value = response.message
        }
        XCTAssertEqual(receivedMessage.value?.hostname, "pong")
    }

    func testMockUnaryAsyncAwait() async {
        let client = Connectrpc_Conformance_V1_TestServiceClientMock()
        client.mockAsyncUnaryCall = { request in
            XCTAssertTrue(request.fillUsername)
            return ResponseMessage(result: .success(.with { $0.hostname = "pong" }))
        }

        let response = await client.unaryCall(request: .with { $0.fillUsername = true })
        XCTAssertEqual(response.message?.hostname, "pong")
    }

    // MARK: - Bidirectional stream

    func testMockBidirectionalStreamCallbacks() {
        let client = Connectrpc_Conformance_V1_TestServiceClientMock()
        let expectedInputs: [Connectrpc_Conformance_V1_StreamingOutputCallRequest] = [
            .with { $0.responseParameters = [.with { $0.size = 123 }] },
            .with { $0.responseParameters = [.with { $0.size = 456 }] },
        ]
        let expectedResults: [StreamResult<Connectrpc_Conformance_V1_StreamingOutputCallResponse>] =
        [
            .headers(["x-header": ["123"]]),
            .message(.with { $0.payload.body = Data(repeating: 0, count: 123) }),
            .message(.with { $0.payload.body = Data(repeating: 0, count: 456) }),
            .complete(code: .ok, error: nil, trailers: nil),
        ]
        XCTAssertFalse(client.mockFullDuplexCall.isClosed)

        var sentInputs = [Connectrpc_Conformance_V1_StreamingOutputCallRequest]()
        var closeCalled = false
        client.mockFullDuplexCall.onSend = { sentInputs.append($0) }
        client.mockFullDuplexCall.onClose = { closeCalled = true }
        client.mockFullDuplexCall.outputs = Array(expectedResults)

        let receivedResults = Locked(
            [StreamResult<Connectrpc_Conformance_V1_StreamingOutputCallResponse>]()
        )
        let stream = client.fullDuplexCall { result in
            receivedResults.perform { $0.append(result) }
        }
        stream.send(expectedInputs[0])
        stream.send(expectedInputs[1])
        stream.close()

        XCTAssertEqual(sentInputs, expectedInputs)
        XCTAssertEqual(client.mockFullDuplexCall.inputs, expectedInputs)
        XCTAssertEqual(receivedResults.value, expectedResults)
        XCTAssertTrue(closeCalled)
        XCTAssertTrue(client.mockFullDuplexCall.isClosed)
    }

    func testMockBidirectionalStreamAsyncAwait() async throws {
        let client = Connectrpc_Conformance_V1_TestServiceClientMock()
        let expectedInputs: [Connectrpc_Conformance_V1_StreamingOutputCallRequest] = [
            .with { $0.responseParameters = [.with { $0.size = 123 }] },
            .with { $0.responseParameters = [.with { $0.size = 456 }] },
        ]
        var expectedResults: [StreamResult<Connectrpc_Conformance_V1_StreamingOutputCallResponse>] =
        [
            .headers(["x-header": ["123"]]),
            .message(.with { $0.payload.body = Data(repeating: 0, count: 123) }),
            .message(.with { $0.payload.body = Data(repeating: 0, count: 456) }),
            .complete(code: .ok, error: nil, trailers: nil),
        ]
        XCTAssertFalse(client.mockAsyncFullDuplexCall.isClosed)

        var sentInputs = [Connectrpc_Conformance_V1_StreamingOutputCallRequest]()
        var closeCalled = false
        client.mockAsyncFullDuplexCall.onSend = { sentInputs.append($0) }
        client.mockAsyncFullDuplexCall.onClose = { closeCalled = true }
        client.mockAsyncFullDuplexCall.outputs = Array(expectedResults)

        let stream = client.fullDuplexCall()
        try stream.send(expectedInputs[0])
        try stream.send(expectedInputs[1])
        stream.close()

        for await result in stream.results() {
            XCTAssertEqual(result, expectedResults.removeFirst())
        }

        XCTAssertEqual(sentInputs, expectedInputs)
        XCTAssertEqual(client.mockAsyncFullDuplexCall.inputs, expectedInputs)
        XCTAssertTrue(expectedResults.isEmpty)
        XCTAssertTrue(closeCalled)
        XCTAssertTrue(client.mockAsyncFullDuplexCall.isClosed)
    }

    // MARK: - Server-only stream

    func testMockServerOnlyStreamCallbacks() {
        let client = Connectrpc_Conformance_V1_TestServiceClientMock()
        let expectedInput = SwiftProtobuf.Google_Protobuf_Empty()
        let expectedResults: [StreamResult<SwiftProtobuf.Google_Protobuf_Empty>] = [
            .headers(["x-header": ["123"]]),
            .message(.init()),
            .message(.init()),
            .complete(code: .ok, error: nil, trailers: nil),
        ]

        var sentInputs = [SwiftProtobuf.Google_Protobuf_Empty]()
        client.mockUnimplementedStreamingOutputCall.onSend = { sentInputs.append($0) }
        client.mockUnimplementedStreamingOutputCall.outputs = Array(expectedResults)

        let receivedResults = Locked([StreamResult<SwiftProtobuf.Google_Protobuf_Empty>]())
        let stream = client.unimplementedStreamingOutputCall { result in
            receivedResults.perform { $0.append(result) }
        }
        stream.send(expectedInput)

        XCTAssertEqual(sentInputs, [expectedInput])
        XCTAssertEqual(client.mockUnimplementedStreamingOutputCall.inputs, [expectedInput])
        XCTAssertEqual(receivedResults.value, expectedResults)
    }

    func testMockServerOnlyStreamAsyncAwait() async throws {
        let client = Connectrpc_Conformance_V1_TestServiceClientMock()
        let expectedInput = Connectrpc_Conformance_V1_StreamingOutputCallRequest.with { request in
            request.responseParameters = [.with { $0.size = 123 }]
        }
        var expectedResults: [StreamResult<Connectrpc_Conformance_V1_StreamingOutputCallResponse>] =
        [
            .headers(["x-header": ["123"]]),
            .message(.with { $0.payload.body = Data(repeating: 0, count: 123) }),
            .message(.with { $0.payload.body = Data(repeating: 0, count: 456) }),
            .complete(code: .ok, error: nil, trailers: nil),
        ]

        var sentInputs = [Connectrpc_Conformance_V1_StreamingOutputCallRequest]()
        client.mockAsyncStreamingOutputCall.onSend = { sentInputs.append($0) }
        client.mockAsyncStreamingOutputCall.outputs = Array(expectedResults)

        let stream = client.streamingOutputCall()
        try stream.send(expectedInput)

        for await result in stream.results() {
            XCTAssertEqual(result, expectedResults.removeFirst())
        }

        XCTAssertEqual(sentInputs, [expectedInput])
        XCTAssertEqual(client.mockAsyncStreamingOutputCall.inputs, [expectedInput])
        XCTAssertTrue(expectedResults.isEmpty)
    }
}
