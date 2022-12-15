// swiftlint:disable file_length

import Connect
import Foundation
import GeneratedExamples
import XCTest

private let kTimeout = TimeInterval(5)

private final class CrosstestClients {
    let connectJSONClient: ProtocolClient
    let connectProtoClient: ProtocolClient
    let grpcWebJSONClient: ProtocolClient
    let grpcWebProtoClient: ProtocolClient

    init(timeout: TimeInterval) {
        let httpClient = CrosstestHTTPClient(timeout: timeout)
        let target = "https://localhost:8081"

        self.connectJSONClient = ProtocolClient(
            target: target,
            httpClient: httpClient,
            ConnectClientOption(),
            JSONClientOption(),
            GzipRequestOption(),
            CompressionMinBytesRequestOption(compressionMinBytes: 10),
            GzipCompressionOption()
        )
        self.connectProtoClient = ProtocolClient(
            target: target,
            httpClient: httpClient,
            ConnectClientOption(),
            ProtoClientOption(),
            GzipRequestOption(),
            CompressionMinBytesRequestOption(compressionMinBytes: 10),
            GzipCompressionOption()
        )
        self.grpcWebJSONClient = ProtocolClient(
            target: target,
            httpClient: httpClient,
            GRPCWebClientOption(),
            JSONClientOption(),
            GzipRequestOption(),
            CompressionMinBytesRequestOption(compressionMinBytes: 10),
            GzipCompressionOption()
        )
        self.grpcWebProtoClient = ProtocolClient(
            target: target,
            httpClient: httpClient,
            GRPCWebClientOption(),
            ProtoClientOption(),
            GzipRequestOption(),
            CompressionMinBytesRequestOption(compressionMinBytes: 10),
            GzipCompressionOption()
        )
    }
}

/// This test suite runs against multiple protocols and serialization formats.
/// Tests are based on https://github.com/bufbuild/connect-crosstest
final class Crosstests: XCTestCase {
    private func executeTestWithClients(
        function: Selector = #function,
        timeout: TimeInterval = 60,
        runTestsWithClient: (TestServiceClient) throws -> Void
    ) rethrows {
        let clients = CrosstestClients(timeout: timeout)

        print("Running \(function) with Connect + JSON...")
        try runTestsWithClient(TestServiceClient(client: clients.connectJSONClient))
        print("Running \(function) with Connect + proto...")
        try runTestsWithClient(TestServiceClient(client: clients.connectProtoClient))

        print("Running \(function) with gRPC Web + JSON...")
        try runTestsWithClient(TestServiceClient(client: clients.grpcWebJSONClient))
        print("Running \(function) with gRPC Web + proto...")
        try runTestsWithClient(TestServiceClient(client: clients.grpcWebProtoClient))
    }

    private func executeTestWithUnimplementedClients(
        function: Selector = #function,
        runTestsWithClient: (UnimplementedServiceClient) throws -> Void
    ) rethrows {
        let clients = CrosstestClients(timeout: 60)

        print("Running \(function) with Connect + JSON...")
        try runTestsWithClient(UnimplementedServiceClient(client: clients.connectJSONClient))
        print("Running \(function) with Connect + proto...")
        try runTestsWithClient(UnimplementedServiceClient(client: clients.connectProtoClient))

        print("Running \(function) with gRPC Web + JSON...")
        try runTestsWithClient(UnimplementedServiceClient(client: clients.grpcWebJSONClient))
        print("Running \(function) with gRPC Web + proto...")
        try runTestsWithClient(UnimplementedServiceClient(client: clients.grpcWebProtoClient))
    }

    // MARK: - Crosstest cases

    func testEmptyUnary() {
        self.executeTestWithClients { client in
            let expectation = self.expectation(description: "Receives successful response")
            client.emptyCall(request: Grpc_Testing_Empty()) { response in
                XCTAssertNil(response.error)
                XCTAssertEqual(response.message, Grpc_Testing_Empty())
                expectation.fulfill()
            }
            XCTAssertEqual(XCTWaiter().wait(for: [expectation], timeout: kTimeout), .completed)
        }
    }

    func testLargeUnary() {
        self.executeTestWithClients { client in
            let size = 314_159
            let message = Grpc_Testing_SimpleRequest.with { proto in
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
            try stream.send(Grpc_Testing_StreamingOutputCallRequest.with { proto in
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
            try stream.send(Grpc_Testing_StreamingOutputCallRequest.with { proto in
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
            let message = Grpc_Testing_SimpleRequest.with { proto in
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
            try stream.send(Grpc_Testing_StreamingOutputCallRequest.with { proto in
                proto.responseParameters = [.with { $0.size = Int32(size) }]
            })

            XCTAssertEqual(XCTWaiter().wait(for: [
                headersExpectation, messageExpectation, trailersExpectation,
            ], timeout: kTimeout, enforceOrder: true), .completed)
        }
    }

    func testStatusCodeAndMessage() {
        let message = Grpc_Testing_SimpleRequest.with { proto in
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
        let message = Grpc_Testing_SimpleRequest.with { proto in
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
            let message = Grpc_Testing_StreamingOutputCallRequest.with { proto in
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
            client.unimplementedCall(request: Grpc_Testing_Empty()) { response in
                XCTAssertEqual(response.code, .unimplemented)
                XCTAssertEqual(
                    response.error?.message,
                    "grpc.testing.TestService.UnimplementedCall is not implemented"
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
                        grpc.testing.TestService.UnimplementedStreamingOutputCall is not implemented
                        """
                    )
                    expectation.fulfill()
                }
            }
            try stream.send(Grpc_Testing_Empty())

            XCTAssertEqual(XCTWaiter().wait(for: [expectation], timeout: kTimeout), .completed)
        }
    }

    func testUnimplementedService() {
        self.executeTestWithUnimplementedClients { client in
            let expectation = self.expectation(description: "Request completes")
            client.unimplementedCall(request: Grpc_Testing_Empty()) { response in
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
            try stream.send(Grpc_Testing_Empty())

            XCTAssertEqual(XCTWaiter().wait(for: [expectation], timeout: kTimeout), .completed)
        }
    }

    func testFailUnary() {
        self.executeTestWithClients { client in
            let expectedErrorDetail = Grpc_Testing_ErrorDetail.with { proto in
                proto.reason = "soirée 🎉"
                proto.domain = "connect-crosstest"
            }
            let expectation = self.expectation(description: "Request completes")
            client.failUnaryCall(request: Grpc_Testing_SimpleRequest()) { response in
                XCTAssertEqual(response.error?.code, .resourceExhausted)
                XCTAssertEqual(response.error?.message, "soirée 🎉")
                XCTAssertEqual(response.error?.unpackedDetails(), expectedErrorDetail)
                expectation.fulfill()
            }

            XCTAssertEqual(XCTWaiter().wait(for: [expectation], timeout: kTimeout), .completed)
        }
    }

    func testFailServerStreaming() throws {
        try self.executeTestWithClients { client in
            let expectedErrorDetail = Grpc_Testing_ErrorDetail.with { proto in
                proto.reason = "soirée 🎉"
                proto.domain = "connect-crosstest"
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
                    XCTAssertEqual(connectError.unpackedDetails(), expectedErrorDetail)
                    expectation.fulfill()
                }
            }
            try stream.send(Grpc_Testing_StreamingOutputCallRequest.with { proto in
                proto.responseParameters = [31_415, 9, 2_653, 58_979]
                    .enumerated()
                    .map { index, value in
                        return Grpc_Testing_ResponseParameters.with { parameters in
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
            let cancelable = client.emptyCall(request: Grpc_Testing_Empty()) { response in
                XCTAssertEqual(response.code, .canceled)
                XCTAssertEqual(response.error?.code, .canceled)
                expectation.fulfill()
            }
            cancelable.cancel()
            XCTAssertEqual(XCTWaiter().wait(for: [expectation], timeout: kTimeout), .completed)
        }
    }
}
