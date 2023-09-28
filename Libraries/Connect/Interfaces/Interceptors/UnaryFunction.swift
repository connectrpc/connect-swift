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

/// A set of closures used by an interceptor to inspect or modify unary requests/responses.
public struct UnaryFunction: Sendable {
    public let requestFunction: RequestHandler
    public let responseFunction: ResponseHandler
    public let responseMetricsFunction: ResponseMetricsHandler

    public typealias RequestHandler = @Sendable (
        _ request: HTTPRequest, _ proceed: @escaping @Sendable (HTTPRequest) -> Void
    ) -> Void
    public typealias ResponseHandler = @Sendable (
        _ response: HTTPResponse, _ proceed: @escaping @Sendable (HTTPResponse) -> Void
    ) -> Void
    public typealias ResponseMetricsHandler = @Sendable (
        _ metrics: HTTPMetrics, _ proceed: @escaping @Sendable (HTTPMetrics) -> Void
    ) -> Void

    public init(
        requestFunction: @escaping RequestHandler,
        responseFunction: @escaping ResponseHandler,
        responseMetricsFunction: @escaping ResponseMetricsHandler = { $1($0) }
    ) {
        self.requestFunction = requestFunction
        self.responseFunction = responseFunction
        self.responseMetricsFunction = responseMetricsFunction
    }
}
