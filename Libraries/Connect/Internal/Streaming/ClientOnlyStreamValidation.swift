// Copyright 2022-2025 The Connect Authors
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

/// Namespace for performing client-only stream validation.
enum ClientOnlyStreamValidation {
    /// Applies some validations which are only relevant for client-only streams.
    ///
    /// Should be called after all values have been received over a client stream. Since client
    /// streams only expect 1 result, all values returned from the server should be buffered before
    /// being validated here and returned to the caller.
    ///
    /// - parameter results: The buffered list of results to validate.
    ///
    /// - returns: The list of stream results which should be returned to the caller.
    static func validatedFinalClientStreamResults<T>(
        _ results: [StreamResult<T>]
    ) -> [StreamResult<T>] {
        var messageCount = 0
        for result in results {
            switch result {
            case .headers:
                continue
            case .message:
                messageCount += 1
            case .complete(let code, _, _):
                if code != .ok {
                    return results
                }
            }
        }

        if messageCount < 1 {
            return [
                .complete(
                    code: .internalError, error: ConnectError(
                        code: .unimplemented, message: "unary stream has no messages"
                    ), trailers: nil
                ),
            ]
        } else if messageCount > 1 {
            return [
                .complete(
                    code: .internalError, error: ConnectError(
                        code: .unimplemented, message: "unary stream has multiple messages"
                    ), trailers: nil
                ),
            ]
        } else {
            return results
        }
    }
}
