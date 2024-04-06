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

/// Enumeration of result states that can be received over streams.
///
/// A typical stream receives `headers > message > message > message ... > complete`.
@frozen
public enum StreamResult<Output: Sendable>: Sendable {
    /// Stream is complete. Provides the end status code and optionally an error and trailers.
    case complete(code: Code, error: Swift.Error?, trailers: Trailers?)
    /// Headers have been received over the stream.
    case headers(Headers)
    /// A response message has been received over the stream.
    case message(Output)

    public var messageValue: Output? {
        switch self {
        case .headers, .complete:
            return nil
        case .message(let output):
            return output
        }
    }
}

extension StreamResult: Equatable where Output: Equatable {
    public static func == (lhs: StreamResult<Output>, rhs: StreamResult<Output>) -> Bool {
        switch (lhs, rhs) {
        case (
            .complete(let code1, let error1, let trailers1),
            .complete(let code2, let error2, let trailers2)
        ):
            return code1 == code2
            && trailers1 == trailers2
            && (error1 != nil) == (error2 != nil)

        case (.headers(let headers1), .headers(let headers2)):
            return headers1 == headers2

        case (.message(let message1), .message(let message2)):
            return message1 == message2

        default:
            return false
        }
    }
}
