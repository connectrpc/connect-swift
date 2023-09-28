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

import Foundation

final class AsyncInterceptor: Interceptor, Sendable {
    func handleRequest(_ request: HTTPRequest) async -> HTTPRequest {
        return request
    }

    func handleUnaryResponse(_ response: HTTPResponse) async -> HTTPResponse {
        return response
    }

    func handleUnaryResponseMetrics(_ metrics: HTTPMetrics) async -> HTTPMetrics {
        return metrics
    }

    func handleStreamRequestData(_ data: Data) async -> Data {
        return data
    }

    func handleStreamResult(_ result: StreamResult<Data>) async -> StreamResult<Data> {
        return result
    }

    final func unaryFunction() -> UnaryFunction {
        return .init { request, proceed in
            Task {
                proceed(await self.handleRequest(request))
            }
        } responseFunction: { response, proceed in
            Task {
                proceed(await self.handleUnaryResponse(response))
            }
        } responseMetricsFunction: { metrics, proceed in
            Task {
                proceed(await self.handleUnaryResponseMetrics(metrics))
            }
        }
    }

    final func streamFunction() -> StreamFunction {
        return .init { request, proceed in
            Task {
                proceed(await self.handleRequest(request))
            }
        } requestDataFunction: { data, proceed in
            Task {
                proceed(await self.handleStreamRequestData(data))
            }
        } streamResultFunction: { result, proceed in
            Task {
                proceed(await self.handleStreamResult(result))
            }
        }
    }
}
