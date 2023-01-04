// Copyright 2022-2023 Buf Technologies, Inc.
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
import ConnectMocks
import Generated
import GeneratedMocks
import SwiftProtobuf
import XCTest

/// Test suite that validates the behavior of generated mock classes.
final class ConnectMocksTests: XCTestCase {
    // MARK: - Unary

    func testMockUnaryCallbacks() {
        let client = Buf_Connect_Demo_Eliza_V1_ElizaServiceClientMock()
        client.mockSay = { request in
            XCTAssertEqual(request.sentence, "ping")
            return ResponseMessage(message: .with { $0.sentence = "pong" })
        }

        var receivedMessage: Buf_Connect_Demo_Eliza_V1_SayResponse?
        client.say(request: .with { $0.sentence = "ping" }) { response in
            receivedMessage = response.message
        }
        XCTAssertEqual(receivedMessage?.sentence, "pong")
    }

    func testMockUnaryAsyncAwait() async {
        let client = Buf_Connect_Demo_Eliza_V1_ElizaServiceClientMock()
        client.mockAsyncSay = { request in
            XCTAssertEqual(request.sentence, "ping")
            return ResponseMessage(message: .with { $0.sentence = "pong" })
        }

        let response = await client.say(request: .with { $0.sentence = "ping" })
        XCTAssertEqual(response.message?.sentence, "pong")
    }

    // MARK: - Bidirectional stream

    func testMockBidirectionalStreamCallbacks() throws {
        let client = Buf_Connect_Demo_Eliza_V1_ElizaServiceClientMock()
        let expectedInputs: [Buf_Connect_Demo_Eliza_V1_ConverseRequest] = [
            .with { $0.sentence = "hello1" },
            .with { $0.sentence = "hello2" },
        ]
        let expectedResults: [StreamResult<Buf_Connect_Demo_Eliza_V1_ConverseResponse>] = [
            .headers(["x-header": ["123"]]),
            .message(.with { $0.sentence = "abc" }),
            .message(.with { $0.sentence = "def" }),
            .complete(code: .ok, error: nil, trailers: nil),
        ]
        XCTAssertFalse(client.mockConverse.isClosed)

        var sentInputs = [Buf_Connect_Demo_Eliza_V1_ConverseRequest]()
        var closeCalled = false
        client.mockConverse.onSend = { sentInputs.append($0) }
        client.mockConverse.onClose = { closeCalled = true }
        client.mockConverse.outputs = Array(expectedResults)

        var receivedResults = [StreamResult<Buf_Connect_Demo_Eliza_V1_ConverseResponse>]()
        let stream = client.converse { receivedResults.append($0) }
        try stream.send(expectedInputs[0])
        try stream.send(expectedInputs[1])
        stream.close()

        XCTAssertEqual(sentInputs, expectedInputs)
        XCTAssertEqual(client.mockConverse.inputs, expectedInputs)
        XCTAssertEqual(receivedResults, expectedResults)
        XCTAssertTrue(closeCalled)
        XCTAssertTrue(client.mockConverse.isClosed)
    }

    func testMockBidirectionalStreamAsyncAwait() async throws {
        let client = Buf_Connect_Demo_Eliza_V1_ElizaServiceClientMock()
        let expectedInputs: [Buf_Connect_Demo_Eliza_V1_ConverseRequest] = [
            .with { $0.sentence = "hello1" },
            .with { $0.sentence = "hello2" },
        ]
        var expectedResults: [StreamResult<Buf_Connect_Demo_Eliza_V1_ConverseResponse>] = [
            .headers(["x-header": ["123"]]),
            .message(.with { $0.sentence = "abc" }),
            .message(.with { $0.sentence = "def" }),
            .complete(code: .ok, error: nil, trailers: nil),
        ]
        XCTAssertFalse(client.mockConverse.isClosed)

        var sentInputs = [Buf_Connect_Demo_Eliza_V1_ConverseRequest]()
        var closeCalled = false
        client.mockAsyncConverse.onSend = { sentInputs.append($0) }
        client.mockAsyncConverse.onClose = { closeCalled = true }
        client.mockAsyncConverse.outputs = Array(expectedResults)

        let stream = client.converse()
        try stream.send(expectedInputs[0])
        try stream.send(expectedInputs[1])
        stream.close()

        for await result in stream.results() {
            XCTAssertEqual(result, expectedResults.removeFirst())
        }

        XCTAssertEqual(sentInputs, expectedInputs)
        XCTAssertEqual(client.mockAsyncConverse.inputs, expectedInputs)
        XCTAssertTrue(expectedResults.isEmpty)
        XCTAssertTrue(closeCalled)
        XCTAssertTrue(client.mockAsyncConverse.isClosed)
    }

    // MARK: - Server-only stream

    func testMockServerOnlyStreamCallbacks() throws {
        let client = Buf_Connect_Demo_Eliza_V1_ElizaServiceClientMock()
        let expectedInput = Buf_Connect_Demo_Eliza_V1_IntroduceRequest.with { $0.name = "michael" }
        let expectedResults: [StreamResult<Buf_Connect_Demo_Eliza_V1_IntroduceResponse>] = [
            .headers(["x-header": ["123"]]),
            .message(.with { $0.sentence = "abc" }),
            .message(.with { $0.sentence = "def" }),
            .complete(code: .ok, error: nil, trailers: nil),
        ]

        var sentInputs = [Buf_Connect_Demo_Eliza_V1_IntroduceRequest]()
        client.mockIntroduce.onSend = { sentInputs.append($0) }
        client.mockIntroduce.outputs = Array(expectedResults)

        var receivedResults = [StreamResult<Buf_Connect_Demo_Eliza_V1_IntroduceResponse>]()
        let stream = client.introduce { receivedResults.append($0) }
        try stream.send(expectedInput)

        XCTAssertEqual(sentInputs, [expectedInput])
        XCTAssertEqual(client.mockIntroduce.inputs, [expectedInput])
        XCTAssertEqual(receivedResults, expectedResults)
    }

    func testMockServerOnlyStreamAsyncAwait() async throws {
        let client = Buf_Connect_Demo_Eliza_V1_ElizaServiceClientMock()
        let expectedInput = Buf_Connect_Demo_Eliza_V1_IntroduceRequest.with { $0.name = "michael" }
        var expectedResults: [StreamResult<Buf_Connect_Demo_Eliza_V1_IntroduceResponse>] = [
            .headers(["x-header": ["123"]]),
            .message(.with { $0.sentence = "abc" }),
            .message(.with { $0.sentence = "def" }),
            .complete(code: .ok, error: nil, trailers: nil),
        ]

        var sentInputs = [Buf_Connect_Demo_Eliza_V1_IntroduceRequest]()
        client.mockAsyncIntroduce.onSend = { sentInputs.append($0) }
        client.mockAsyncIntroduce.outputs = Array(expectedResults)

        let stream = client.introduce()
        try stream.send(expectedInput)

        for await result in stream.results() {
            XCTAssertEqual(result, expectedResults.removeFirst())
        }

        XCTAssertEqual(sentInputs, [expectedInput])
        XCTAssertEqual(client.mockAsyncIntroduce.inputs, [expectedInput])
        XCTAssertTrue(expectedResults.isEmpty)
    }
}
