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

import Foundation

/// A set of closures used by an interceptor to inspect or modify streams.
public struct StreamFunction: Sendable {
    public let requestFunction: RequestHandler
    public let requestDataFunction: RequestDataHandler
    public let streamResultFunction: StreamResultHandler

    public typealias RequestHandler = @Sendable (
        _ request: HTTPRequest,
        _ proceed: @escaping @Sendable (Result<HTTPRequest, ConnectError>) -> Void
    ) -> Void
    public typealias RequestDataHandler = @Sendable (
        _ data: Data, _ proceed: @escaping @Sendable (Data) -> Void
    ) -> Void
    public typealias StreamResultHandler = @Sendable (
        _ result: StreamResult<Data>, _ proceed: @escaping @Sendable (StreamResult<Data>) -> Void
    ) -> Void

    public init(
        requestFunction: @escaping RequestHandler,
        requestDataFunction: @escaping RequestDataHandler,
        streamResultFunction: @escaping StreamResultHandler
    ) {
        self.requestFunction = requestFunction
        self.requestDataFunction = requestDataFunction
        self.streamResultFunction = streamResultFunction
    }
}
