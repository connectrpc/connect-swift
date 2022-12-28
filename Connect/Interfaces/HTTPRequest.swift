//
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
//

import Foundation

/// HTTP request used for sending primitive data to the server.
public struct HTTPRequest {
    /// Target URL for the request.
    public let target: URL
    /// Value to assign to the `content-type` header.
    public let contentType: String
    /// Additional outbound headers for the request.
    public let headers: Headers
    /// Body data to send with the request.
    public let message: Data?

    public init(target: URL, contentType: String, headers: Headers, message: Data?) {
        self.target = target
        self.contentType = contentType
        self.headers = headers
        self.message = message
    }
}