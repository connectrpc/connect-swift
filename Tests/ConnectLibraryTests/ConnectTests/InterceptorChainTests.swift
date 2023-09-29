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
import XCTest

private struct MockUnaryInterceptor: Interceptor {
    let headerID: String
    let requestExpectation: XCTestExpectation
    let responseExpectation: XCTestExpectation
    let responseMetricsExpectation: XCTestExpectation

    func unaryFunction() -> UnaryFunction {
        return UnaryFunction { request, proceed in
            var headers = request.headers
            headers["filter-chain", default: []].append(self.headerID)
            self.requestExpectation.fulfill()
            proceed(HTTPRequest(
                url: request.url,
                contentType: request.contentType,
                headers: headers,
                message: request.message,
                trailers: request.trailers
            ))
        } responseFunction: { response, proceed in
            var headers = response.headers
            headers["filter-chain", default: []].append(self.headerID)
            self.responseExpectation.fulfill()
            proceed(HTTPResponse(
                code: response.code,
                headers: headers,
                message: response.message,
                trailers: response.trailers,
                error: response.error,
                tracingInfo: .init(httpStatus: 200)
            ))
        } responseMetricsFunction: { metrics, proceed in
            self.responseMetricsExpectation.fulfill()
            proceed(metrics)
        }
    }

    func streamFunction() -> StreamFunction {
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
        return StreamFunction { request, proceed in
            var headers = request.headers
            headers["filter-chain", default: []].append(self.headerID)
            self.requestExpectation.fulfill()
            proceed(HTTPRequest(
                url: request.url,
                contentType: request.contentType,
                headers: headers,
                message: request.message,
                trailers: Trailers()
            ))
        } requestDataFunction: { data, proceed in
            self.requestDataExpectation.fulfill()
            proceed(self.outboundMessageData)
        } streamResultFunction: { result, proceed in
            self.resultExpectation.fulfill()
            switch result {
            case .headers(let headers):
                var headers = headers
                headers["filter-chain", default: []].append(self.headerID)
                proceed(.headers(headers))

            case .message:
                proceed(.message(self.inboundMessageData))

            case .complete(let code, let error, let trailers):
                var trailers = trailers ?? [:]
                trailers["filter-chain", default: []].append(self.headerID)
                proceed(.complete(code: code, error: error, trailers: trailers))
            }
        }
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
        let chain = InterceptorChain([
            MockUnaryInterceptor(
                headerID: "filter-a",
                requestExpectation: aRequestExpectation,
                responseExpectation: aResponseExpectation,
                responseMetricsExpectation: aMetricsExpectation
            ).unaryFunction(),
            MockUnaryInterceptor(
                headerID: "filter-b",
                requestExpectation: bRequestExpectation,
                responseExpectation: bResponseExpectation,
                responseMetricsExpectation: bMetricsExpectation
            ).unaryFunction(),
        ])

        let interceptedRequest = Locked<HTTPRequest?>(nil)
        chain.executeInterceptors(
            \.requestFunction,
             firstInFirstOut: true,
             initial: HTTPRequest(
                url: try XCTUnwrap(URL(string: "https://buf.build/mock")),
                contentType: "application/json",
                headers: Headers(),
                message: nil,
                trailers: Trailers()
             ), finish: { interceptedRequest.value = $0 }
        )
        XCTAssertEqual(interceptedRequest.value?.headers["filter-chain"], ["filter-a", "filter-b"])

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
             ), finish: { interceptedResponse.value = $0 }
        )
        XCTAssertEqual(interceptedResponse.value?.headers["filter-chain"], ["filter-b", "filter-a"])

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
        let chain = InterceptorChain([
            MockStreamInterceptor(
                headerID: "filter-a",
                outboundMessageData: filterAData,
                inboundMessageData: filterAData,
                requestExpectation: aRequestExpectation,
                requestDataExpectation: aRequestDataExpectation,
                resultExpectation: aResultExpectation
            ).streamFunction(),
            MockStreamInterceptor(
                headerID: "filter-b",
                outboundMessageData: filterBData,
                inboundMessageData: filterBData,
                requestExpectation: bRequestExpectation,
                requestDataExpectation: bRequestDataExpectation,
                resultExpectation: bResultExpectation
            ).streamFunction(),
        ])

        let interceptedRequest = Locked<HTTPRequest?>(nil)
        chain.executeInterceptors(
            \.requestFunction,
             firstInFirstOut: true,
             initial: HTTPRequest(
                url: try XCTUnwrap(URL(string: "https://buf.build/mock")),
                contentType: "application/json",
                headers: Headers(),
                message: nil,
                trailers: Trailers()
             ),
             finish: { interceptedRequest.value = $0 }
        )
        XCTAssertEqual(interceptedRequest.value?.headers["filter-chain"], ["filter-a", "filter-b"])
        XCTAssertNil(interceptedRequest.value?.message)

        let interceptedRequestData = Locked<Data?>(nil)
        chain.executeInterceptors(
            \.requestDataFunction,
             firstInFirstOut: true,
             initial: Data(),
             finish: { interceptedRequestData.value = $0 }
        )
        XCTAssertEqual(interceptedRequestData.value, filterBData)

        let interceptedResult = Locked<StreamResult<Data>?>(nil)
        chain.executeInterceptors(
            \.streamResultFunction,
             firstInFirstOut: false,
             initial: .headers(Headers()),
             finish: { interceptedResult.value = $0 }
        )
        XCTAssertEqual(
            interceptedResult.value, .headers(["filter-chain": ["filter-b", "filter-a"]])
        )

        chain.executeInterceptors(
            \.streamResultFunction,
             firstInFirstOut: false,
             initial: .message(Data()),
             finish: { interceptedResult.value = $0 }
        )
        XCTAssertEqual(interceptedResult.value, .message(filterAData))

        chain.executeInterceptors(
            \.streamResultFunction,
             firstInFirstOut: false,
             initial: .complete(code: .ok, error: nil, trailers: nil),
             finish: { interceptedResult.value = $0 }
        )
        switch interceptedResult.value {
        case .complete(_, _, let interceptedTrailers):
            XCTAssertEqual(interceptedTrailers?["filter-chain"], ["filter-b", "filter-a"])
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
}
