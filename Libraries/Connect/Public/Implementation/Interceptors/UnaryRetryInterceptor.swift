// Copyright 2022-2024 The Connect Authors
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

import Dispatch
import Foundation

/// Interceptor that can be used to retry unary requests automatically.
public final class UnaryRetryInterceptor: @unchecked Sendable {
    private let codesToRetry: Set<Code>
    private let delayForRetryNumber: @Sendable (Int) -> TimeInterval
    private let maxNumberOfRetries: Int

    private var retries = 0
    private var sendRequest: (() -> Void)!

    /// Create a new instance of the retry interceptor.
    ///
    /// - parameter maxNumberOfRetries: The maximum number of times a request should be retried.
    /// - parameter codesToRetry: The codes that should be retried.
    /// - parameter delayForRetryNumber: Closure that will be invoked to determine how long to
    ///                                  wait before retrying a request. The integer input
    ///                                  represents the retry number (i.e., 1 is the first retry).
    ///                                  Will not be invoked for the initial request.
    public init(
        maxNumberOfRetries: Int,
        codesToRetry: Set<Code>,
        delayForRetryNumber: @escaping @Sendable (Int) -> TimeInterval
    ) {
        self.maxNumberOfRetries = maxNumberOfRetries
        self.codesToRetry = codesToRetry
        self.delayForRetryNumber = delayForRetryNumber
    }
}

extension UnaryRetryInterceptor: UnaryInterceptor {
    public func handleUnaryRawRequest(
        _ request: HTTPRequest<Data?>,
        proceed: @escaping (Result<HTTPRequest<Data?>, ConnectError>) -> Void
    ) {
        self.sendRequest = {
            proceed(.success(HTTPRequest(
                url: URL(string: "https://demo.connectrpc.com/\(request.url.path)")!,
                headers: request.headers,
                message: request.message,
                method: request.method,
                trailers: request.trailers,
                idempotencyLevel: request.idempotencyLevel)))
        }
        proceed(.success(request))
    }

    public func handleUnaryRawResponse(
        _ response: HTTPResponse,
        proceed: @escaping (HTTPResponse) -> Void
    ) {
        print("**Response \(response.code)")
        guard response.code != .ok,
              self.codesToRetry.contains(response.code),
              self.retries < self.maxNumberOfRetries
        else {
            proceed(response)
            return
        }

        self.retries += 1
        let delayMS = Int(self.delayForRetryNumber(self.retries) * 1_000)
        DispatchQueue
            .global(qos: .userInitiated)
            .asyncAfter(deadline: .now() + .milliseconds(delayMS)) { [weak self] in
                print("**Retrying \(response.code)...")
                self?.sendRequest()
            }
    }
}
