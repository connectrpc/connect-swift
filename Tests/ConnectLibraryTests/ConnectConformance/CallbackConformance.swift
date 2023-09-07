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

// swiftlint:disable file_length

import Connect
import Foundation
import SwiftProtobuf
import XCTest

private let kTimeout = TimeInterval(10.0)

private typealias TestServiceClient = Connectrpc_Conformance_V1_TestServiceClient
private typealias UnimplementedServiceClient = Connectrpc_Conformance_V1_UnimplementedServiceClient

/// This test suite runs against multiple protocols and serialization formats.
/// Tests are based on https://github.com/connectrpc/conformance
///
/// Tests are written using callback APIs.
final class CallbackConformance: XCTestCase {
    private func executeTestWithClients(
        function: Selector = #function,
        timeout: TimeInterval = 60,
        runTestsWithClient: (TestServiceClient) throws -> Void
    ) rethrows {
        let configurations = ConformanceConfiguration.all(timeout: timeout)
        for configuration in configurations {
            try runTestsWithClient(TestServiceClient(client: configuration.protocolClient))
            print("Ran \(function) with \(configuration.description)")
        }
    }

    private func executeTestWithUnimplementedClients(
        function: Selector = #function,
        runTestsWithClient: (UnimplementedServiceClient) throws -> Void
    ) rethrows {
        let configurations = ConformanceConfiguration.all(timeout: 60)
        for configuration in configurations {
            try runTestsWithClient(UnimplementedServiceClient(client: configuration.protocolClient))
            print("Ran \(function) with \(configuration.description)")
        }
    }

    // MARK: - Conformance cases

    func testEmptyUnary() {
        self.executeTestWithClients { client in
            let expectation = self.expectation(description: "Receives successful response")
            client.emptyCall(request: SwiftProtobuf.Google_Protobuf_Empty()) { response in
                XCTAssertNil(response.error)
                XCTAssertEqual(response.message, SwiftProtobuf.Google_Protobuf_Empty())
                expectation.fulfill()
            }
            XCTAssertEqual(XCTWaiter().wait(for: [expectation], timeout: kTimeout), .completed)
        }
    }

    func testLargeUnary() {
        self.executeTestWithClients { client in
            let size = 314_159
            let message = Connectrpc_Conformance_V1_SimpleRequest.with { proto in
                proto.responseSize = Int32(size)
                proto.payload = .with { $0.body = Data(repeating: 0, count: size) }
            }
            let expectation = self.expectation(description: "Receives successful response")
            client.unaryCall(request: message) { response in
                XCTAssertNil(response.error)
                XCTAssertEqual(response.message?.payload.body.count, size)
                expectation.fulfill()
            }
            XCTAssertEqual(XCTWaiter().wait(for: [expectation], timeout: kTimeout), .completed)
        }
    }

    func testServerStreaming() throws {
        try self.executeTestWithClients { client in
            let sizes = [31_415, 9, 2_653, 58_979]
            let expectation = self.expectation(description: "Stream completes")
            var responseCount = 0
            let stream = client.streamingOutputCall { result in
                switch result {
                case .headers:
                    break

                case .message(let output):
                    XCTAssertEqual(output.payload.body.count, sizes[responseCount])
                    responseCount += 1

                case .complete(let code, let error, _):
                    XCTAssertEqual(code, .ok)
                    XCTAssertNil(error)
                    expectation.fulfill()
                }
            }
            try stream.send(Connectrpc_Conformance_V1_StreamingOutputCallRequest.with { proto in
                proto.responseParameters = sizes.enumerated().map { index, size in
                    return .with { parameters in
                        parameters.size = Int32(size)
                        parameters.intervalUs = Int32(index * 10)
                    }
                }
            })

            XCTAssertEqual(XCTWaiter().wait(for: [expectation], timeout: kTimeout), .completed)
            XCTAssertEqual(responseCount, 4)
        }
    }

    func testEmptyStream() throws {
        try self.executeTestWithClients { client in
            let closeExpectation = self.expectation(description: "Stream completes")
            let stream = client.streamingOutputCall { result in
                switch result {
                case .headers:
                    break

                case .message:
                    XCTFail("Unexpectedly received message")

                case .complete(let code, let error, _):
                    XCTAssertEqual(code, .ok)
                    XCTAssertNil(error)
                    closeExpectation.fulfill()
                }
            }
            try stream.send(Connectrpc_Conformance_V1_StreamingOutputCallRequest.with { proto in
                proto.responseParameters = []
            })

            XCTAssertEqual(XCTWaiter().wait(for: [closeExpectation], timeout: kTimeout), .completed)
        }
    }

    func testCustomMetadata() {
        self.executeTestWithClients { client in
            let size = 314_159
            let leadingKey = "x-grpc-test-echo-initial"
            let leadingValue = "test_initial_metadata_value"
            let trailingKey = "x-grpc-test-echo-trailing-bin"
            let trailingValue = Data([0xab, 0xab, 0xab])
            let headers: Headers = [
                leadingKey: [leadingValue],
                trailingKey: [trailingValue.base64EncodedString()],
            ]
            let message = Connectrpc_Conformance_V1_SimpleRequest.with { proto in
                proto.responseSize = Int32(size)
                proto.payload = .with { $0.body = Data(repeating: 0, count: size) }
            }

            let expectation = self.expectation(description: "Receives response")
            client.unaryCall(request: message, headers: headers) { response in
                XCTAssertEqual(response.code, .ok)
                XCTAssertNil(response.error)
                XCTAssertEqual(response.headers[leadingKey], [leadingValue])
                XCTAssertEqual(
                    response.trailers[trailingKey], [trailingValue.base64EncodedString()]
                )
                XCTAssertEqual(response.message?.payload.body.count, size)
                expectation.fulfill()
            }

            XCTAssertEqual(XCTWaiter().wait(for: [expectation], timeout: kTimeout), .completed)
        }
    }

    func testCustomMetadataServerStreaming() throws {
        let size = 314_159
        let leadingKey = "x-grpc-test-echo-initial"
        let leadingValue = "test_initial_metadata_value"
        let trailingKey = "x-grpc-test-echo-trailing-bin"
        let trailingValue = Data([0xab, 0xab, 0xab])
        let headers: Headers = [
            leadingKey: [leadingValue],
            trailingKey: [trailingValue.base64EncodedString()],
        ]

        try self.executeTestWithClients { client in
            let headersExpectation = self.expectation(description: "Receives headers")
            let messageExpectation = self.expectation(description: "Receives message")
            let trailersExpectation = self.expectation(description: "Receives trailers")
            let stream = client.streamingOutputCall(headers: headers) { result in
                switch result {
                case .headers(let headers):
                    XCTAssertEqual(headers[leadingKey], [leadingValue])
                    headersExpectation.fulfill()

                case .message(let message):
                    XCTAssertEqual(message.payload.body.count, size)
                    messageExpectation.fulfill()

                case .complete(let code, let error, let trailers):
                    XCTAssertEqual(code, .ok)
                    XCTAssertEqual(trailers?[trailingKey], [trailingValue.base64EncodedString()])
                    XCTAssertNil(error)
                    trailersExpectation.fulfill()
                }
            }
            try stream.send(Connectrpc_Conformance_V1_StreamingOutputCallRequest.with { proto in
                proto.responseParameters = [.with { $0.size = Int32(size) }]
            })

            XCTAssertEqual(XCTWaiter().wait(for: [
                headersExpectation, messageExpectation, trailersExpectation,
            ], timeout: kTimeout, enforceOrder: true), .completed)
        }
    }

    func testStatusCodeAndMessage() {
        let message = Connectrpc_Conformance_V1_SimpleRequest.with { proto in
            proto.responseStatus = .with { status in
                status.code = Int32(Code.unknown.rawValue)
                status.message = "test status message"
            }
        }

        self.executeTestWithClients { client in
            let expectation = self.expectation(description: "Receives response")
            client.unaryCall(request: message) { response in
                guard let error = response.error else {
                    XCTFail("Expected error response")
                    return
                }
                XCTAssertEqual(error.code, .unknown)
                XCTAssertEqual(error.message, "test status message")
                expectation.fulfill()
            }

            XCTAssertEqual(XCTWaiter().wait(for: [expectation], timeout: kTimeout), .completed)
        }
    }

    func testSpecialStatus() {
        let statusMessage =
            "\\t\\ntest with whitespace\\r\\nand Unicode BMP ☺ and non-BMP \\uD83D\\uDE08\\t\\n"
        let message = Connectrpc_Conformance_V1_SimpleRequest.with { proto in
            proto.responseStatus = .with { status in
                status.code = 2
                status.message = statusMessage
            }
        }

        self.executeTestWithClients { client in
            let expectation = self.expectation(description: "Receives response")
            client.unaryCall(request: message) { response in
                guard let error = response.error else {
                    XCTFail("Expected error response")
                    return
                }
                XCTAssertEqual(error.code, .unknown)
                XCTAssertEqual(error.message, statusMessage)
                expectation.fulfill()
            }

            XCTAssertEqual(XCTWaiter().wait(for: [expectation], timeout: kTimeout), .completed)
        }
    }

    func testTimeoutOnSleepingServer() throws {
        try self.executeTestWithClients(timeout: 0.01) { client in
            let expectation = self.expectation(description: "Stream times out")
            let message = Connectrpc_Conformance_V1_StreamingOutputCallRequest.with { proto in
                proto.payload = .with { $0.body = Data(count: 271_828) }
                proto.responseParameters = [
                    .with { parameters in
                        parameters.size = 31_415
                        parameters.intervalUs = 50_000
                    },
                ]
            }
            let stream = client.streamingOutputCall { result in
                switch result {
                case .headers:
                    break

                case .message:
                    break

                case .complete(let code, let error, _):
                    XCTAssertEqual(code, .deadlineExceeded)
                    XCTAssertNotNil(error)
                    expectation.fulfill()
                }
            }
            try stream.send(message)

            XCTAssertEqual(XCTWaiter().wait(for: [expectation], timeout: kTimeout), .completed)
        }
    }

    func testUnimplementedMethod() {
        self.executeTestWithClients { client in
            let expectation = self.expectation(description: "Request completes")
            client.unimplementedCall(request: SwiftProtobuf.Google_Protobuf_Empty()) { response in
                XCTAssertEqual(response.code, .unimplemented)
                XCTAssertEqual(
                    response.error?.message,
                    "connectrpc.conformance.v1.TestService.UnimplementedCall is not implemented"
                )
                expectation.fulfill()
            }

            XCTAssertEqual(XCTWaiter().wait(for: [expectation], timeout: kTimeout), .completed)
        }
    }

    func testUnimplementedServerStreamingMethod() throws {
        try self.executeTestWithClients { client in
            let expectation = self.expectation(description: "Stream completes")
            let stream = client.unimplementedStreamingOutputCall { result in
                switch result {
                case .headers, .message:
                    break

                case .complete(let code, let error, _):
                    XCTAssertEqual(code, .unimplemented)
                    XCTAssertEqual(
                        (error as? ConnectError)?.message,
                        """
                        connectrpc.conformance.v1.TestService.UnimplementedStreamingOutputCall is \
                        not implemented
                        """
                    )
                    expectation.fulfill()
                }
            }
            try stream.send(SwiftProtobuf.Google_Protobuf_Empty())

            XCTAssertEqual(XCTWaiter().wait(for: [expectation], timeout: kTimeout), .completed)
        }
    }

    func testUnimplementedService() {
        self.executeTestWithUnimplementedClients { client in
            let expectation = self.expectation(description: "Request completes")
            client.unimplementedCall(request: SwiftProtobuf.Google_Protobuf_Empty()) { response in
                XCTAssertEqual(response.code, .unimplemented)
                XCTAssertNotNil(response.error)
                expectation.fulfill()
            }

            XCTAssertEqual(XCTWaiter().wait(for: [expectation], timeout: kTimeout), .completed)
        }
    }

    func testUnimplementedServerStreamingService() throws {
        try self.executeTestWithUnimplementedClients { client in
            let expectation = self.expectation(description: "Stream completes")
            let stream = client.unimplementedStreamingOutputCall { result in
                switch result {
                case .headers:
                    break

                case .message:
                    XCTFail("Unexpectedly received message")

                case .complete(let code, _, _):
                    XCTAssertEqual(code, .unimplemented)
                    expectation.fulfill()
                }
            }
            try stream.send(SwiftProtobuf.Google_Protobuf_Empty())

            XCTAssertEqual(XCTWaiter().wait(for: [expectation], timeout: kTimeout), .completed)
        }
    }

    func testFailUnary() {
        self.executeTestWithClients { client in
            let expectedErrorDetail = Connectrpc_Conformance_V1_ErrorDetail.with { proto in
                proto.reason = "soirée 🎉"
                proto.domain = "connect-conformance"
            }
            let expectation = self.expectation(description: "Request completes")
            client.failUnaryCall(request: Connectrpc_Conformance_V1_SimpleRequest()) { response in
                XCTAssertEqual(response.error?.code, .resourceExhausted)
                XCTAssertEqual(response.error?.message, "soirée 🎉")
                XCTAssertEqual(response.error?.unpackedDetails(), [expectedErrorDetail])
                expectation.fulfill()
            }

            XCTAssertEqual(XCTWaiter().wait(for: [expectation], timeout: kTimeout), .completed)
        }
    }

    func testFailServerStreaming() throws {
        try self.executeTestWithClients { client in
            let expectedErrorDetail = Connectrpc_Conformance_V1_ErrorDetail.with { proto in
                proto.reason = "soirée 🎉"
                proto.domain = "connect-conformance"
            }
            let expectation = self.expectation(description: "Stream completes")
            let stream = client.failStreamingOutputCall { result in
                switch result {
                case .headers:
                    break

                case .message:
                    XCTFail("Unexpectedly received message")

                case .complete(_, let error, _):
                    guard let connectError = error as? ConnectError else {
                        XCTFail("Expected ConnectError")
                        return
                    }

                    XCTAssertEqual(connectError.code, .resourceExhausted)
                    XCTAssertEqual(connectError.message, "soirée 🎉")
                    XCTAssertEqual(connectError.unpackedDetails(), [expectedErrorDetail])
                    expectation.fulfill()
                }
            }
            try stream.send(Connectrpc_Conformance_V1_StreamingOutputCallRequest.with { proto in
                proto.responseParameters = [31_415, 9, 2_653, 58_979]
                    .enumerated()
                    .map { index, value in
                        return Connectrpc_Conformance_V1_ResponseParameters.with { parameters in
                            parameters.size = Int32(value)
                            parameters.intervalUs = Int32(index * 10)
                        }
                    }
            })

            XCTAssertEqual(XCTWaiter().wait(for: [expectation], timeout: kTimeout), .completed)
        }
    }

    // MARK: - Additional cases

    func testCancelingUnary() {
        self.executeTestWithClients { client in
            let expectation = self.expectation(description: "Receives canceled response")
            let cancelable = client.emptyCall(
                request: SwiftProtobuf.Google_Protobuf_Empty()) { response in
                    XCTAssertEqual(response.code, .canceled)
                    XCTAssertEqual(response.error?.code, .canceled)
                    expectation.fulfill()
            }
            cancelable.cancel()
            XCTAssertEqual(XCTWaiter().wait(for: [expectation], timeout: kTimeout), .completed)
        }
    }
}
