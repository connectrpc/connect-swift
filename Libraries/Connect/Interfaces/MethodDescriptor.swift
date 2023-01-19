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

/// Contains metadata on a specifific RPC method.
public struct MethodDescriptor: Equatable {
    /// The name of the RPC method (1:1 with the `.proto` file).
    public let name: String
    /// The path of the RPC, constructed using the package, service, and RPC name.
    public let path: String

    public init(name: String, path: String) {
        self.name = name
        self.path = path
    }
}
