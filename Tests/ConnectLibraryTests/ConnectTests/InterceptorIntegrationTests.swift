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
import SwiftProtobuf
import XCTest

@available(iOS 16, *)
@available(tvOS 16, *)
@available(watchOS 9, *)
final class InterceptorIntegrationTests: XCTestCase {
    func testUnaryInterceptorSuccess() async {
        let trackedSteps = Locked([InterceptorStep]())
        let client = self.createClient(interceptors: [
            InterceptorFactory { _ in
                StepTrackingInterceptor(
                    id: "a",
                    trackUsing: trackedSteps
                )
            },
            InterceptorFactory { _ in
                StepTrackingInterceptor(
                    id: "b",
                    trackUsing: trackedSteps
                )
            },
        ])
        let response = await client.emptyCall(request: SwiftProtobuf.Google_Protobuf_Empty())
        XCTAssertNil(response.error)
        XCTAssertEqual(trackedSteps.value, [
            .unaryRequest(id: "a"),
            .unaryRequest(id: "b"),
            .unaryRawRequest(id: "a"),
            .unaryRawRequest(id: "b"),
            .unaryRawResponse(id: "b"),
            .unaryRawResponse(id: "a"),
            .unaryResponse(id: "b"),
            .unaryResponse(id: "a"),
        ])
    }

    func testStreamInterceptorSuccess() async throws {
        let trackedSteps = Locked([InterceptorStep]())
        let client = self.createClient(interceptors: [
            InterceptorFactory { _ in
                StepTrackingInterceptor(
                    id: "a",
                    trackUsing: trackedSteps
                )
            },
            InterceptorFactory { _ in
                StepTrackingInterceptor(
                    id: "b",
                    trackUsing: trackedSteps
                )
            },
        ])
        let stream = client.fullDuplexCall()
        try stream.send(.with { $0.responseParameters = [.with { $0.size = 100 }] })
        if let firstResponse = await stream.results().first(where: { $0.messageValue != nil }) {
            XCTAssertEqual(firstResponse.messageValue?.payload.body.count, 100)
        }
        try stream.send(.with { $0.responseParameters = [.with { $0.size = 200 }] })
        if let secondResponse = await stream.results().first(where: { $0.messageValue != nil }) {
            XCTAssertEqual(secondResponse.messageValue?.payload.body.count, 200)
        }
        stream.close()
        for await result in stream.results() {
            if case .complete(let code, _, _) = result {
                XCTAssertEqual(code, .ok)
            }
        }

        XCTAssertEqual(trackedSteps.value, [
            .streamStart(id: "a"),
            .streamStart(id: "b"),
            .streamInput(id: "a"),
            .streamInput(id: "b"),
            .streamRawInput(id: "a"),
            .streamRawInput(id: "b"),
            .streamRawResult(id: "b", type: "headers"),
            .streamRawResult(id: "a", type: "headers"),
            .streamResult(id: "b", type: "headers"),
            .streamResult(id: "a", type: "headers"),
            .streamRawResult(id: "b", type: "message"),
            .streamRawResult(id: "a", type: "message"),
            .streamResult(id: "b", type: "message"),
            .streamResult(id: "a", type: "message"),
            .streamInput(id: "a"),
            .streamInput(id: "b"),
            .streamRawInput(id: "a"),
            .streamRawInput(id: "b"),
            .streamRawResult(id: "b", type: "message"),
            .streamRawResult(id: "a", type: "message"),
            .streamResult(id: "b", type: "message"),
            .streamResult(id: "a", type: "message"),
            .streamRawResult(id: "b", type: "complete"),
            .streamRawResult(id: "a", type: "complete"),
            .streamResult(id: "b", type: "complete"),
            .streamResult(id: "a", type: "complete"),
        ])
    }

    func testUnaryInterceptorIsCalledWithMetrics() async {
        let trackedSteps = Locked([InterceptorStep]())
        let client = self.createClient(interceptors: [
            InterceptorFactory { _ in
                StepTrackingInterceptor(
                    id: "a",
                    trackUsing: trackedSteps,
                    trackMetrics: true
                )
            },
            InterceptorFactory { _ in
                StepTrackingInterceptor(
                    id: "b",
                    trackUsing: trackedSteps,
                    trackMetrics: true
                )
            },
        ])
        let response = await client.emptyCall(request: SwiftProtobuf.Google_Protobuf_Empty())
        XCTAssertNil(response.error)

        // Subset of steps is tested since URLSession does not guarantee metric callback ordering.
        XCTAssertTrue(trackedSteps.value.contains(
            [.responseMetrics(id: "b"), .responseMetrics(id: "a")]
        ))
    }

    func testStreamInterceptorIsCalledWithMetrics() async throws {
        let trackedSteps = Locked([InterceptorStep]())
        let client = self.createClient(interceptors: [
            InterceptorFactory { _ in
                StepTrackingInterceptor(
                    id: "a",
                    trackUsing: trackedSteps,
                    trackMetrics: true
                )
            },
            InterceptorFactory { _ in
                StepTrackingInterceptor(
                    id: "b",
                    trackUsing: trackedSteps,
                    trackMetrics: true
                )
            },
        ])
        let stream = client.streamingOutputCall()
        try stream.send(Connectrpc_Conformance_V1_StreamingOutputCallRequest())
        for await result in stream.results() {
            if case .complete(let code, _, _) = result {
                XCTAssertEqual(code, .ok)
            }
            sleep(1) // URLSession sometimes produces metrics information late.
        }

        // Subset of steps is tested since URLSession does not guarantee metric callback ordering.
        XCTAssertTrue(trackedSteps.value.contains(
            [.responseMetrics(id: "b"), .responseMetrics(id: "a")]
        ))
    }

    func testUnaryInterceptorCanFailOutboundRequest() async {
        let trackedSteps = Locked([InterceptorStep]())
        let client = self.createClient(interceptors: [
            InterceptorFactory { _ in
                // Will return an error immediately when sending the request.
                StepTrackingInterceptor(
                    id: "a",
                    failOutboundRequests: true,
                    trackUsing: trackedSteps
                )
            },
            InterceptorFactory { _ in
                // Should never be invoked if the request is failed by the previous interceptor.
                StepTrackingInterceptor(
                    id: "b",
                    failOutboundRequests: false,
                    trackUsing: trackedSteps
                )
            },
        ])
        let response = await client.emptyCall(request: SwiftProtobuf.Google_Protobuf_Empty())
        XCTAssertNotNil(response.error) // Interceptor failed the request.
        XCTAssertEqual(trackedSteps.value, [
            .unaryRequest(id: "a"),
            // Second interceptor is never called.
        ])
    }

    func testStreamInterceptorCanFailOutboundRequest() async {
        let trackedSteps = Locked([InterceptorStep]())
        let client = self.createClient(interceptors: [
            InterceptorFactory { _ in
                // Will return an error immediately when sending the request.
                StepTrackingInterceptor(
                    id: "a",
                    failOutboundRequests: true,
                    trackUsing: trackedSteps
                )
            },
            InterceptorFactory { _ in
                // Should never be invoked if the request is failed by the previous interceptor.
                StepTrackingInterceptor(
                    id: "b",
                    failOutboundRequests: false,
                    trackUsing: trackedSteps
                )
            },
        ])
        for await result in client.streamingOutputCall().results() {
            switch result {
            case .complete(_, let error, _):
                XCTAssertNotNil(error) // Interceptor failed the request.
            default:
                XCTFail("Unexpected result")
            }
        }
        XCTAssertEqual(trackedSteps.value, [
            .streamStart(id: "a"),
            // Second interceptor is never called.
        ])
    }

    func testStreamDoesNotPassRequestDataToInterceptorsUntilRequestHeadersAreSent() async throws {
        let trackedSteps = Locked([InterceptorStep]())
        let client = self.createClient(interceptors: [
            InterceptorFactory { _ in
                StepTrackingInterceptor(
                    id: "a",
                    requestDelay: .milliseconds(100), // Simulate async processing of headers.
                    trackUsing: trackedSteps
                )
            },
            InterceptorFactory { _ in
                StepTrackingInterceptor(
                    id: "b",
                    requestDelay: .never,
                    trackUsing: trackedSteps
                )
            },
        ])

        let stream = client.streamingOutputCall()
        // Send data immediately (before the first interceptor has finished processing headers).
        try stream.send(Connectrpc_Conformance_V1_StreamingOutputCallRequest())
        for await result in stream.results() {
            if case .complete(let code, _, _) = result {
                XCTAssertEqual(code, .ok)
            }
        }

        // The client should wait for all interceptors to finish processing headers before it
        // passes any data through the chain.
        XCTAssertEqual(trackedSteps.value, [
            .streamStart(id: "a"),
            .streamStart(id: "b"),
            .streamInput(id: "a"),
            .streamInput(id: "b"),
            .streamRawInput(id: "a"),
            .streamRawInput(id: "b"),
            .streamRawResult(id: "b", type: "headers"),
            .streamRawResult(id: "a", type: "headers"),
            .streamResult(id: "b", type: "headers"),
            .streamResult(id: "a", type: "headers"),
            .streamRawResult(id: "b", type: "complete"),
            .streamRawResult(id: "a", type: "complete"),
            .streamResult(id: "b", type: "complete"),
            .streamResult(id: "a", type: "complete"),
        ])
    }

    // MARK: - Private

    private func createClient(
        interceptors: [InterceptorFactory]
    ) -> Connectrpc_Conformance_V1_TestServiceClient {
        let protocolClient = ProtocolClient(
            httpClient: ConformanceURLSessionHTTPClient(timeout: 60),
            config: ProtocolClientConfig(host: "https://localhost:8081", interceptors: interceptors)
        )
        return Connectrpc_Conformance_V1_TestServiceClient(client: protocolClient)
    }
}

private enum InterceptorStep: Equatable {
    case responseMetrics(id: String)
    case streamStart(id: String)
    case streamInput(id: String)
    case streamRawInput(id: String)
    case streamResult(id: String, type: String)
    case streamRawResult(id: String, type: String)
    case unaryRequest(id: String)
    case unaryRawRequest(id: String)
    case unaryResponse(id: String)
    case unaryRawResponse(id: String)
}

private final class StepTrackingInterceptor: Interceptor {
    private let failOutboundRequests: Bool
    private let id: String
    private let requestDelay: DispatchTimeInterval
    private let steps: Locked<[InterceptorStep]>
    private let trackMetrics: Bool

    init(
        id: String,
        failOutboundRequests: Bool = false,
        requestDelay: DispatchTimeInterval = .never,
        trackUsing steps: Locked<[InterceptorStep]>,
        trackMetrics: Bool = false
    ) {
        self.id = id
        self.failOutboundRequests = failOutboundRequests
        self.requestDelay = requestDelay
        self.steps = steps
        self.trackMetrics = trackMetrics
    }

    @Sendable
    func handleResponseMetrics(
        _ metrics: HTTPMetrics,
        proceed: @escaping @Sendable (HTTPMetrics) -> Void
    ) {
        if self.trackMetrics {
            self.trackStep(.responseMetrics(id: self.id))
        }
        proceed(metrics)
    }

    private func trackStep(_ step: InterceptorStep) {
        self.steps.perform { $0.append(step) }
    }
}

extension StepTrackingInterceptor: UnaryInterceptor {
    @Sendable
    func handleUnaryRequest<Message: ProtobufMessage>(
        _ request: HTTPRequest<Message>,
        proceed: @escaping @Sendable (Result<HTTPRequest<Message>, ConnectError>) -> Void
    ) {
        self.trackStep(.unaryRequest(id: self.id))
        if self.failOutboundRequests {
            proceed(.failure(.from(code: .aborted, headers: Headers(), source: nil)))
        } else if self.requestDelay != .never {
            DispatchQueue.global().asyncAfter(deadline: .now() + self.requestDelay) {
                proceed(.success(request))
            }
        } else {
            proceed(.success(request))
        }
    }

    @Sendable
    func handleUnaryRawRequest(
        _ request: HTTPRequest<Data?>,
        proceed: @escaping @Sendable (Result<HTTPRequest<Data?>, ConnectError>) -> Void
    ) {
        self.trackStep(.unaryRawRequest(id: self.id))
        proceed(.success(request))
    }

    @Sendable
    func handleUnaryResponse<Message: ProtobufMessage>(
        _ response: ResponseMessage<Message>,
        proceed: @escaping @Sendable (ResponseMessage<Message>) -> Void
    ) {
        self.trackStep(.unaryResponse(id: self.id))
        proceed(response)
    }

    @Sendable
    func handleUnaryRawResponse(
        _ response: HTTPResponse,
        proceed: @escaping @Sendable (HTTPResponse) -> Void
    ) {
        self.trackStep(.unaryRawResponse(id: self.id))
        proceed(response)
    }
}

extension StepTrackingInterceptor: StreamInterceptor {
    @Sendable
    func handleStreamStart(
        _ request: HTTPRequest<Void>,
        proceed: @escaping @Sendable (Result<HTTPRequest<Void>, ConnectError>) -> Void
    ) {
        self.trackStep(.streamStart(id: self.id))
        if self.failOutboundRequests {
            proceed(.failure(.from(code: .aborted, headers: Headers(), source: nil)))
        } else if self.requestDelay != .never {
            DispatchQueue.global().asyncAfter(deadline: .now() + self.requestDelay) {
                proceed(.success(request))
            }
        } else {
            proceed(.success(request))
        }
    }

    @Sendable
    func handleStreamInput<Message: ProtobufMessage>(
        _ input: Message,
        proceed: @escaping @Sendable (Message) -> Void
    ) {
        self.trackStep(.streamInput(id: self.id))
        proceed(input)
    }

    @Sendable
    func handleStreamRawInput(
        _ input: Data,
        proceed: @escaping @Sendable (Data) -> Void
    ) {
        self.trackStep(.streamRawInput(id: self.id))
        proceed(input)
    }

    @Sendable
    func handleStreamResult<Message: ProtobufMessage>(
        _ result: StreamResult<Message>,
        proceed: @escaping @Sendable (StreamResult<Message>) -> Void
    ) {
        switch result {
        case .headers:
            self.trackStep(.streamResult(id: self.id, type: "headers"))
        case .message:
            self.trackStep(.streamResult(id: self.id, type: "message"))
        case .complete:
            self.trackStep(.streamResult(id: self.id, type: "complete"))
        }
        proceed(result)
    }

    @Sendable
    func handleStreamRawResult(
        _ result: StreamResult<Data>,
        proceed: @escaping @Sendable (StreamResult<Data>) -> Void
    ) {
        switch result {
        case .headers:
            self.trackStep(.streamRawResult(id: self.id, type: "headers"))
        case .message:
            self.trackStep(.streamRawResult(id: self.id, type: "message"))
        case .complete:
            self.trackStep(.streamRawResult(id: self.id, type: "complete"))
        }
        proceed(result)
    }
}
