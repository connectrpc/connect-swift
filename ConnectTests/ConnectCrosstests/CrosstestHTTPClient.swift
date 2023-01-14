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
import Foundation

/// HTTP client used by crosstests in order to handle SSL challenges with the crosstest server.
final class CrosstestHTTPClient: URLSessionHTTPClient {
    private let delayAfterChallenge: TimeInterval?

    init(timeout: TimeInterval, delayAfterChallenge: TimeInterval? = nil) {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = timeout
        configuration.timeoutIntervalForResource = timeout
        self.delayAfterChallenge = delayAfterChallenge
        super.init(configuration: configuration)
    }

    func urlSession(
        _ session: URLSession, didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        let finishRequest = {
            // This codepath is executed when using HTTPS with the crosstest server.
            let protectionSpace = challenge.protectionSpace
            if protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
               let serverTrust = protectionSpace.serverTrust
            {
                completionHandler(.useCredential, URLCredential(trust: serverTrust))
            } else {
                completionHandler(.performDefaultHandling, nil)
            }
        }

        if let delayAfterChallenge = self.delayAfterChallenge {
            DispatchQueue.main.asyncAfter(
                deadline: .now() + .milliseconds(Int(delayAfterChallenge * 1_000)),
                execute: finishRequest
            )
        } else {
            finishRequest()
        }
    }
}
