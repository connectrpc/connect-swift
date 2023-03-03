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

@testable import Connect
import XCTest

private struct MockUnaryInterceptor: Interceptor {
    let headerID: String
    let requestExpectation: XCTestExpectation
    let responseExpectation: XCTestExpectation
    let responseMetricsExpectation: XCTestExpectation

    func unaryFunction() -> Connect.UnaryFunction {
        return UnaryFunction(
            requestFunction: { request in
                var headers = request.headers
                headers["filter-chain", default: []].append(self.headerID)
                self.requestExpectation.fulfill()
                return HTTPRequest(
                    url: request.url,
                    contentType: request.contentType,
                    headers: headers,
                    message: request.message
                )
            },
            responseFunction: { response in
                var headers = response.headers
                headers["filter-chain", default: []].append(self.headerID)
                self.responseExpectation.fulfill()
                return HTTPResponse(
                    code: response.code,
                    headers: headers,
                    message: response.message,
                    trailers: response.trailers,
                    error: response.error,
                    tracingInfo: .init(httpStatus: 200)
                )
            },
            responseMetricsFunction: { metrics in
                self.responseMetricsExpectation.fulfill()
                return metrics
            }
        )
    }

    func streamFunction() -> Connect.StreamFunction {
        fatalError("Unexpectedly called with stream")
    }
}

private struct MockStreamInterceptor: Interceptor {
    let headerID: String
    let outboundMessageData: Data
    let inboundMessageData: Data
    let requestExpectation: XCTestExpectation
    let requestDataExpectation: XCTestExpectation
    let resultExpectation: XCTestExpectation

    func unaryFunction() -> UnaryFunction {
        fatalError("Unexpectedly called with unary request")
    }

    func streamFunction() -> StreamFunction {
        return StreamFunction(
            requestFunction: { request in
                var headers = request.headers
                headers["filter-chain", default: []].append(self.headerID)
                self.requestExpectation.fulfill()
                return HTTPRequest(
                    url: request.url,
                    contentType: request.contentType,
                    headers: headers,
                    message: request.message
                )
            },
            requestDataFunction: { _ in
                self.requestDataExpectation.fulfill()
                return self.outboundMessageData
            },
            streamResultFunc: { result in
                self.resultExpectation.fulfill()
                switch result {
                case .headers(let headers):
                    var headers = headers
                    headers["filter-chain", default: []].append(self.headerID)
                    return .headers(headers)

                case .message:
                    return .message(self.inboundMessageData)

                case .complete(let code, let error, let trailers):
                    var trailers = trailers ?? [:]
                    trailers["filter-chain", default: []].append(self.headerID)
                    return .complete(code: code, error: error, trailers: trailers)
                }
            }
        )
    }
}

final class InterceptorChainTests: XCTestCase {
    private let config = ProtocolClientConfig(host: "https://buf.build")

    func testUnary() throws {
        let aRequestExpectation = self.expectation(description: "Filter A called with request")
        let bRequestExpectation = self.expectation(description: "Filter B called with request")
        let aResponseExpectation = self.expectation(description: "Filter A called with response")
        let bResponseExpectation = self.expectation(description: "Filter B called with response")
        let aMetricsExpectation = self.expectation(description: "Filter A called with metrics")
        let bMetricsExpectation = self.expectation(description: "Filter B called with metrics")
        let chain = InterceptorChain(
            interceptors: [
                { _ in
                    return MockUnaryInterceptor(
                        headerID: "filter-a",
                        requestExpectation: aRequestExpectation,
                        responseExpectation: aResponseExpectation,
                        responseMetricsExpectation: aMetricsExpectation
                    )
                },
                { _ in
                    return MockUnaryInterceptor(
                        headerID: "filter-b",
                        requestExpectation: bRequestExpectation,
                        responseExpectation: bResponseExpectation,
                        responseMetricsExpectation: bMetricsExpectation
                    )
                },
            ],
            config: self.config
        ).unaryFunction()

        let interceptedRequest = chain.requestFunction(HTTPRequest(
            url: try XCTUnwrap(URL(string: "https://buf.build/mock")),
            contentType: "application/json",
            headers: Headers(),
            message: nil
        ))
        XCTAssertEqual(interceptedRequest.headers["filter-chain"], ["filter-a", "filter-b"])

        let interceptedResponse = chain.responseFunction(HTTPResponse(
            code: .ok,
            headers: Headers(),
            message: nil,
            trailers: Trailers(),
            error: nil,
            tracingInfo: .init(httpStatus: 200)
        ))
        XCTAssertEqual(interceptedResponse.headers["filter-chain"], ["filter-b", "filter-a"])

        XCTAssertEqual(XCTWaiter().wait(for: [
            aRequestExpectation,
            bRequestExpectation,
            bResponseExpectation,
            aResponseExpectation,
            aMetricsExpectation,
            bMetricsExpectation,
        ], timeout: 1.0, enforceOrder: true), .completed)
    }

    func testStream() throws {
        let aRequestExpectation = self.expectation(description: "Filter A called with request")
        let bRequestExpectation = self.expectation(description: "Filter B called with request")
        let aRequestDataExpectation = self.expectation(description: "Filter A called with data")
        let bRequestDataExpectation = self.expectation(description: "Filter B called with data")
        let aResultExpectation = self.expectation(description: "Filter A called with result")
        aResultExpectation.expectedFulfillmentCount = 3
        let bResultExpectation = self.expectation(description: "Filter B called with result")
        bResultExpectation.expectedFulfillmentCount = 3

        let filterAData = try XCTUnwrap("filter a".data(using: .utf8))
        let filterBData = try XCTUnwrap("filter b".data(using: .utf8))
        let chain = InterceptorChain(
            interceptors: [
                { _ in
                    return MockStreamInterceptor(
                        headerID: "filter-a",
                        outboundMessageData: filterAData,
                        inboundMessageData: filterAData,
                        requestExpectation: aRequestExpectation,
                        requestDataExpectation: aRequestDataExpectation,
                        resultExpectation: aResultExpectation
                    )
                },
                { _ in
                    return MockStreamInterceptor(
                        headerID: "filter-b",
                        outboundMessageData: filterBData,
                        inboundMessageData: filterBData,
                        requestExpectation: bRequestExpectation,
                        requestDataExpectation: bRequestDataExpectation,
                        resultExpectation: bResultExpectation
                    )
                },
            ],
            config: self.config
        ).streamFunction()

        let interceptedRequest = chain.requestFunction(HTTPRequest(
            url: try XCTUnwrap(URL(string: "https://buf.build/mock")),
            contentType: "application/json",
            headers: Headers(),
            message: nil
        ))
        XCTAssertEqual(interceptedRequest.headers["filter-chain"], ["filter-a", "filter-b"])
        XCTAssertNil(interceptedRequest.message)

        let interceptedRequestData = chain.requestDataFunction(Data())
        XCTAssertEqual(interceptedRequestData, filterBData)

        switch chain.streamResultFunc(.headers(Headers())) {
        case .headers(let interceptedResultHeaders):
            XCTAssertEqual(interceptedResultHeaders["filter-chain"], ["filter-b", "filter-a"])
        case .message, .complete:
            XCTFail("Unexpected result")
        }

        switch chain.streamResultFunc(.message(Data())) {
        case .message(let interceptedData):
            XCTAssertEqual(interceptedData, filterAData)
        case .headers, .complete:
            XCTFail("Unexpected result")
        }

        switch chain.streamResultFunc(.complete(code: .ok, error: nil, trailers: nil)) {
        case .complete(_, _, let interceptedTrailers):
            XCTAssertEqual(interceptedTrailers?["filter-chain"], ["filter-b", "filter-a"])
        case .headers, .message:
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
}
