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

private struct MockUnaryInterceptor: Interceptor {
    let failOutboundRequests: Bool
    let headerID: String
    let requestExpectation: XCTestExpectation?
    let responseExpectation: XCTestExpectation?
    let responseMetricsExpectation: XCTestExpectation?

    func unaryFunction() -> UnaryFunction {
        return UnaryFunction { request, proceed in
            self.requestExpectation?.fulfill()
            if self.failOutboundRequests {
                proceed(.failure(ConnectError(
                    code: .unknown, message: "request failed by interceptor",
                    exception: nil, details: [], metadata: [:]
                )))
                return
            }

            var headers = request.headers
            headers["interceptor-chain", default: []].append(self.headerID)
            proceed(.success(HTTPRequest(
                url: request.url,
                contentType: request.contentType,
                headers: headers,
                message: request.message, 
                method: request.method,
                trailers: request.trailers,
                idempotencyLevel: request.idempotencyLevel
            )))
        } responseFunction: { response, proceed in
            var headers = response.headers
            headers["interceptor-chain", default: []].append(self.headerID)
            self.responseExpectation?.fulfill()
            proceed(HTTPResponse(
                code: response.code,
                headers: headers,
                message: response.message,
                trailers: response.trailers,
                error: response.error,
                tracingInfo: .init(httpStatus: 200)
            ))
        } responseMetricsFunction: { metrics, proceed in
            self.responseMetricsExpectation?.fulfill()
            proceed(metrics)
        }
    }

    func streamFunction() -> StreamFunction {
        fatalError("Unexpectedly called with stream")
    }
}

private struct MockStreamInterceptor: Interceptor {
    let failOutboundRequests: Bool
    let headerID: String
    let requestDelayMS: Int
    let requestData: Data
    let responseData: Data
    let requestExpectation: XCTestExpectation?
    let requestDataExpectation: XCTestExpectation?
    let resultExpectation: XCTestExpectation?

    func unaryFunction() -> UnaryFunction {
        fatalError("Unexpectedly called with unary request")
    }

    func streamFunction() -> StreamFunction {
        return StreamFunction { request, proceed in
            self.requestExpectation?.fulfill()
            if self.failOutboundRequests {
                proceed(.failure(ConnectError(
                    code: .unknown, message: "request failed by interceptor",
                    exception: nil, details: [], metadata: [:]
                )))
                return
            }

            let finish = { @Sendable in
                var headers = request.headers
                headers["interceptor-chain", default: []].append(self.headerID)
                proceed(.success(HTTPRequest(
                    url: request.url,
                    contentType: request.contentType,
                    headers: headers,
                    message: request.message, 
                    method: request.method,
                    trailers: Trailers(),
                    idempotencyLevel: request.idempotencyLevel
                )))
            }
            if self.requestDelayMS > 0 {
                DispatchQueue.main.asyncAfter(
                    deadline: .now() + .milliseconds(self.requestDelayMS),
                    execute: finish
                )
            } else {
                finish()
            }
        } requestDataFunction: { _, proceed in
            self.requestDataExpectation?.fulfill()
            proceed(self.requestData)
        } streamResultFunction: { result, proceed in
            self.resultExpectation?.fulfill()
            switch result {
            case .headers(let headers):
                var headers = headers
                headers["interceptor-chain", default: []].append(self.headerID)
                proceed(.headers(headers))

            case .message:
                proceed(.message(self.responseData))

            case .complete(let code, let error, let trailers):
                var trailers = trailers ?? [:]
                trailers["interceptor-chain", default: []].append(self.headerID)
                proceed(.complete(code: code, error: error, trailers: trailers))
            }
        }
    }
}

final class InterceptorChainTests: XCTestCase {
    // MARK: - Invoking chain directly

    func testUnarySuccess() throws {
        let aRequestExpectation = self.expectation(description: "A called with request")
        let bRequestExpectation = self.expectation(description: "B called with request")
        let aResponseExpectation = self.expectation(description: "A called with response")
        let bResponseExpectation = self.expectation(description: "B called with response")
        let aMetricsExpectation = self.expectation(description: "A called with metrics")
        let bMetricsExpectation = self.expectation(description: "B called with metrics")
        let chain = InterceptorChain([
            MockUnaryInterceptor(
                failOutboundRequests: false,
                headerID: "interceptor-a",
                requestExpectation: aRequestExpectation,
                responseExpectation: aResponseExpectation,
                responseMetricsExpectation: aMetricsExpectation
            ).unaryFunction(),
            MockUnaryInterceptor(
                failOutboundRequests: false,
                headerID: "interceptor-b",
                requestExpectation: bRequestExpectation,
                responseExpectation: bResponseExpectation,
                responseMetricsExpectation: bMetricsExpectation
            ).unaryFunction(),
        ])

        let interceptedRequest = Locked<HTTPRequest?>(nil)
        chain.executeInterceptorsAndStopOnFailure(
            \.requestFunction,
            firstInFirstOut: true,
            initial: HTTPRequest(
                url: try XCTUnwrap(URL(string: "https://connectrpc.com/mock")),
                contentType: "application/json",
                headers: Headers(),
                message: nil,
                method: .post,
                trailers: Trailers(),
                idempotencyLevel: .unknown
            ),
            finish: { interceptedRequest.value = try? $0.get() }
        )
        XCTAssertEqual(
            interceptedRequest.value?.headers["interceptor-chain"],
            ["interceptor-a", "interceptor-b"]
        )

        let interceptedResponse = Locked<HTTPResponse?>(nil)
        chain.executeInterceptors(
            \.responseFunction,
            firstInFirstOut: false,
            initial: HTTPResponse(
                code: .ok,
                headers: Headers(),
                message: nil,
                trailers: Trailers(),
                error: nil,
                tracingInfo: .init(httpStatus: 200)
            ),
            finish: { interceptedResponse.value = $0 }
        )
        XCTAssertEqual(
            interceptedResponse.value?.headers["interceptor-chain"],
            ["interceptor-b", "interceptor-a"]
        )

        let interceptedMetrics = Locked<HTTPMetrics?>(nil)
        chain.executeInterceptors(
            \.responseMetricsFunction,
            firstInFirstOut: false,
            initial: HTTPMetrics(taskMetrics: nil),
            finish: { interceptedMetrics.value = $0 }
        )
        XCTAssertNil(try XCTUnwrap(interceptedMetrics.value).taskMetrics)

        XCTAssertEqual(XCTWaiter().wait(for: [
            aRequestExpectation,
            bRequestExpectation,
            bResponseExpectation,
            aResponseExpectation,
            bMetricsExpectation,
            aMetricsExpectation,
        ], timeout: 1.0, enforceOrder: true), .completed)
    }

    func testUnaryFailureInInterceptor() throws {
        let aRequestExpectation = self.expectation(description: "A called with request")
        let bRequestExpectation = self.expectation(description: "B called with request")
        bRequestExpectation.isInverted = true
        let interceptorsCompleteExpectation = self.expectation(description: "Interceptors complete")
        let chain = InterceptorChain([
            // Will return an error immediately when sending the request.
            MockUnaryInterceptor(
                failOutboundRequests: true,
                headerID: "interceptor-a",
                requestExpectation: aRequestExpectation,
                responseExpectation: nil,
                responseMetricsExpectation: nil
            ).unaryFunction(),
            // Should never be invoked if the request is failed by the previous interceptor.
            MockUnaryInterceptor(
                failOutboundRequests: false,
                headerID: "interceptor-b",
                requestExpectation: bRequestExpectation,
                responseExpectation: nil,
                responseMetricsExpectation: nil
            ).unaryFunction(),
        ])

        chain.executeInterceptorsAndStopOnFailure(
            \.requestFunction,
            firstInFirstOut: true,
            initial: HTTPRequest(
               url: try XCTUnwrap(URL(string: "https://connectrpc.com/mock")),
               contentType: "application/json",
               headers: Headers(),
               message: nil,
               method: .post,
               trailers: Trailers(),
               idempotencyLevel: .unknown
            ),
            finish: { interceptedResult in
                switch interceptedResult {
                case .success:
                    XCTFail("Expected error from first interceptor")
                case .failure:
                    interceptorsCompleteExpectation.fulfill()
                }
            }
        )

        XCTAssertEqual(XCTWaiter().wait(for: [
            aRequestExpectation,
            bRequestExpectation,
            interceptorsCompleteExpectation,
        ], timeout: 1.0), .completed)
    }

    func testStreamSuccess() throws {
        let aRequestExpectation = self.expectation(description: "A called with request")
        let bRequestExpectation = self.expectation(description: "B called with request")
        let aRequestDataExpectation = self.expectation(description: "A called with data")
        let bRequestDataExpectation = self.expectation(description: "B called with data")
        let aResultExpectation = self.expectation(description: "A called with result")
        aResultExpectation.expectedFulfillmentCount = 3
        let bResultExpectation = self.expectation(description: "B called with result")
        bResultExpectation.expectedFulfillmentCount = 3

        let interceptorAData = try XCTUnwrap("interceptor a".data(using: .utf8))
        let interceptorBData = try XCTUnwrap("interceptor b".data(using: .utf8))
        let chain = InterceptorChain([
            MockStreamInterceptor(
                failOutboundRequests: false,
                headerID: "interceptor-a",
                requestDelayMS: 0,
                requestData: interceptorAData,
                responseData: interceptorAData,
                requestExpectation: aRequestExpectation,
                requestDataExpectation: aRequestDataExpectation,
                resultExpectation: aResultExpectation
            ).streamFunction(),
            MockStreamInterceptor(
                failOutboundRequests: false,
                headerID: "interceptor-b",
                requestDelayMS: 0,
                requestData: interceptorBData,
                responseData: interceptorBData,
                requestExpectation: bRequestExpectation,
                requestDataExpectation: bRequestDataExpectation,
                resultExpectation: bResultExpectation
            ).streamFunction(),
        ])

        let interceptedRequest = Locked<HTTPRequest?>(nil)
        chain.executeInterceptorsAndStopOnFailure(
            \.requestFunction,
            firstInFirstOut: true,
            initial: HTTPRequest(
                url: try XCTUnwrap(URL(string: "https://connectrpc.com/mock")),
                contentType: "application/json",
                headers: Headers(),
                message: nil,
                method: .post,
                trailers: Trailers(),
                idempotencyLevel: .unknown
            ),
            finish: { interceptedRequest.value = try? $0.get() }
        )
        XCTAssertEqual(
            interceptedRequest.value?.headers["interceptor-chain"],
            ["interceptor-a", "interceptor-b"]
        )
        XCTAssertNil(interceptedRequest.value?.message)

        let interceptedRequestData = Locked<Data?>(nil)
        chain.executeInterceptors(
            \.requestDataFunction,
            firstInFirstOut: true,
            initial: Data(),
            finish: { interceptedRequestData.value = $0 }
        )
        XCTAssertEqual(interceptedRequestData.value, interceptorBData)

        let interceptedResult = Locked<StreamResult<Data>?>(nil)
        chain.executeInterceptors(
            \.streamResultFunction,
            firstInFirstOut: false,
            initial: .headers(Headers()),
            finish: { interceptedResult.value = $0 }
        )
        XCTAssertEqual(
            interceptedResult.value,
            .headers(["interceptor-chain": ["interceptor-b", "interceptor-a"]])
        )

        chain.executeInterceptors(
            \.streamResultFunction,
            firstInFirstOut: false,
            initial: .message(Data()),
            finish: { interceptedResult.value = $0 }
        )
        XCTAssertEqual(interceptedResult.value, .message(interceptorAData))

        chain.executeInterceptors(
            \.streamResultFunction,
            firstInFirstOut: false,
            initial: .complete(code: .ok, error: nil, trailers: nil),
            finish: { interceptedResult.value = $0 }
        )
        switch interceptedResult.value {
        case .complete(_, _, let interceptedTrailers):
            XCTAssertEqual(
                interceptedTrailers?["interceptor-chain"],
                ["interceptor-b", "interceptor-a"]
            )
        case .headers, .message, .none:
            XCTFail("Unexpected result")
        }

        XCTAssertEqual(XCTWaiter().wait(for: [
            aRequestExpectation,
            bRequestExpectation,
            aRequestDataExpectation,
            bRequestDataExpectation,
            bResultExpectation,
            aResultExpectation,
        ], timeout: 1.0, enforceOrder: true), .completed)
    }

    func testStreamFailureInInterceptor() throws {
        let aRequestExpectation = self.expectation(description: "A called with request")
        let bRequestExpectation = self.expectation(description: "B called with request")
        bRequestExpectation.isInverted = true
        let interceptorsCompleteExpectation = self.expectation(description: "Interceptors complete")

        let chain = InterceptorChain([
            // Will return an error immediately when sending the request.
            MockStreamInterceptor(
                failOutboundRequests: true,
                headerID: "interceptor-a",
                requestDelayMS: 0,
                requestData: Data(),
                responseData: Data(),
                requestExpectation: aRequestExpectation,
                requestDataExpectation: nil,
                resultExpectation: nil
            ).streamFunction(),
            // Should never be invoked if the request is failed by the previous interceptor.
            MockStreamInterceptor(
                failOutboundRequests: false,
                headerID: "interceptor-b",
                requestDelayMS: 0,
                requestData: Data(),
                responseData: Data(),
                requestExpectation: bRequestExpectation,
                requestDataExpectation: nil,
                resultExpectation: nil
            ).streamFunction(),
        ])

        chain.executeInterceptorsAndStopOnFailure(
            \.requestFunction,
            firstInFirstOut: true,
            initial: HTTPRequest(
               url: try XCTUnwrap(URL(string: "https://connectrpc.com/mock")),
               contentType: "application/json",
               headers: Headers(),
               message: nil,
               method: .post,
               trailers: Trailers(),
               idempotencyLevel: .unknown
            ),
            finish: { interceptedResult in
                switch interceptedResult {
                case .success:
                    XCTFail("Expected error from first interceptor")
                case .failure:
                    interceptorsCompleteExpectation.fulfill()
                }
            }
        )

        XCTAssertEqual(XCTWaiter().wait(for: [
            aRequestExpectation,
            bRequestExpectation,
            interceptorsCompleteExpectation,
        ], timeout: 1.0), .completed)
    }

    // MARK: - Integrating with a client

    func testUnaryInterceptorCanFailOutboundRequest() async {
        let aRequestExpectation = self.expectation(description: "A called")
        let bRequestExpectation = self.expectation(description: "B called")
        bRequestExpectation.isInverted = true
        let client = self.createClient(interceptors: [
            { _ in
                // Will return an error immediately when sending the request.
                MockUnaryInterceptor(
                    failOutboundRequests: true,
                    headerID: "interceptor-a",
                    requestExpectation: aRequestExpectation,
                    responseExpectation: nil,
                    responseMetricsExpectation: nil
                )
            },
            { _ in
                // Should never be invoked if the request is failed by the previous interceptor.
                MockUnaryInterceptor(
                    failOutboundRequests: false,
                    headerID: "interceptor-b",
                    requestExpectation: bRequestExpectation,
                    responseExpectation: nil,
                    responseMetricsExpectation: nil
                )
            },
        ])
        let response = await client.emptyCall(request: .init())
        XCTAssertNotNil(response.error) // Interceptor failed the request.
        XCTAssertEqual(XCTWaiter().wait(for: [
            aRequestExpectation,
            bRequestExpectation,
        ], timeout: 1.0, enforceOrder: true), .completed)
    }

    func testStreamInterceptorCanFailOutboundRequest() async {
        let aRequestExpectation = self.expectation(description: "A called")
        let bRequestExpectation = self.expectation(description: "B called")
        bRequestExpectation.isInverted = true
        let client = self.createClient(interceptors: [
            { _ in
                // Will return an error immediately when sending the request.
                MockStreamInterceptor(
                    failOutboundRequests: true,
                    headerID: "interceptor-a",
                    requestDelayMS: 0,
                    requestData: Data(),
                    responseData: Data(),
                    requestExpectation: aRequestExpectation,
                    requestDataExpectation: nil,
                    resultExpectation: nil
                )
            },
            { _ in
                // Should never be invoked if the request is failed by the previous interceptor.
                MockStreamInterceptor(
                    failOutboundRequests: false,
                    headerID: "interceptor-b",
                    requestDelayMS: 0,
                    requestData: Data(),
                    responseData: Data(),
                    requestExpectation: bRequestExpectation,
                    requestDataExpectation: nil,
                    resultExpectation: nil
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
        XCTAssertEqual(XCTWaiter().wait(for: [
            aRequestExpectation,
            bRequestExpectation,
        ], timeout: 1.0, enforceOrder: true), .completed)
    }

    func testStreamDoesNotPassRequestDataToInterceptorsUntilRequestHeadersAreSent() async throws {
        let aRequestExpectation = self.expectation(description: "A called with request")
        let bRequestExpectation = self.expectation(description: "B called with request")
        let aRequestDataExpectation = self.expectation(description: "A called with data")
        let bRequestDataExpectation = self.expectation(description: "B called with data")
        let client = self.createClient(interceptors: [
            { _ in
                MockStreamInterceptor(
                    failOutboundRequests: false,
                    headerID: "interceptor-a",
                    requestDelayMS: 100, // Simulate asynchronous work while processing headers.
                    requestData: Data(),
                    responseData: Data(),
                    requestExpectation: aRequestExpectation,
                    requestDataExpectation: aRequestDataExpectation,
                    resultExpectation: nil
                )
            },
            { _ in
                MockStreamInterceptor(
                    failOutboundRequests: false,
                    headerID: "interceptor-a",
                    requestDelayMS: 0,
                    requestData: Data(),
                    responseData: Data(),
                    requestExpectation: bRequestExpectation,
                    requestDataExpectation: bRequestDataExpectation,
                    resultExpectation: nil
                )
            },
        ])
        let call = client.streamingOutputCall()

        // Send data immediately (before the first interceptor has finished processing headers).
        try call.send(.init())

        // The client should wait for all interceptors to finish processing headers before it
        // passes any data through the chain. Validate this by enforcing order of expectations.
        XCTAssertEqual(XCTWaiter().wait(for: [
            aRequestExpectation,
            bRequestExpectation,
            aRequestDataExpectation,
            bRequestDataExpectation,
        ], timeout: 1.0, enforceOrder: true), .completed)
    }

    private func createClient(
        interceptors: [InterceptorInitializer]
    ) -> Connectrpc_Conformance_V1_TestServiceClient {
        let protocolClient = ProtocolClient(config: ProtocolClientConfig(
            host: "https://localhost",
            interceptors: interceptors
        ))
        return Connectrpc_Conformance_V1_TestServiceClient(client: protocolClient)
    }
}
