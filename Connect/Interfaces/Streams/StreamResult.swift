// Copyright 2022 Buf Technologies, Inc.
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
public enum StreamResult<Output> {
    /// Stream is complete. Provides the end status code and optionally an error and trailers.
    case complete(code: Code, error: Swift.Error?, trailers: Trailers?)
    /// Headers have been received over the stream.
    case headers(Headers)
    /// A response message has been received over the stream.
    case message(Output)
}
