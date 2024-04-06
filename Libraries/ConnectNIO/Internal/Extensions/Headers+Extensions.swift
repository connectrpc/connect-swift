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

// MARK: - NIO type extensions

extension NIOHTTP1.HTTPHeaders {
    mutating func addNIOHeadersFromConnect(_ headers: Connect.Headers) {
        for (name, value) in headers {
            self.add(name: name, value: value.joined(separator: ","))
        }
    }
}

// MARK: - Connect type extensions

extension Headers {
    static func fromNIOHeaders(_ nioHeaders: NIOHTTP1.HTTPHeaders) -> Self {
        return nioHeaders.reduce(into: [:]) { headers, current in
            let headerName = current.name.lowercased()
            for value in current.value.components(separatedBy: ",") {
                headers[headerName, default: []].append(value.trimmingCharacters(in: .whitespaces))
            }
        }
    }
}

extension Code {
    static func fromNIOStatus(_ nioStatus: NIOHTTP1.HTTPResponseStatus) -> Self {
        return .fromHTTPStatus(Int(nioStatus.code))
    }
}
