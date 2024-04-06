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

import Connect
import Foundation
import NIOHTTP1

extension HTTPRequestHead {
    static func fromConnect(
        _ request: Connect.HTTPRequest<Data?>, nioHeaders: NIOHTTP1.HTTPHeaders
    ) -> Self {
        switch request.method {
        case .get:
            return HTTPRequestHead(
                version: .http1_1,
                method: .GET,
                uri: "\(request.url.path)?\(request.url.query ?? "")",
                headers: nioHeaders
            )
        case .post:
            return HTTPRequestHead(
                version: .http1_1,
                method: .POST,
                uri: request.url.path,
                headers: nioHeaders
            )
        }
    }
}
