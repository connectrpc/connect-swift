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

import SwiftProtobufPluginLibrary

extension ServiceDescriptor {
    public var servicePath: String {
        if self.file.package.isEmpty {
            return self.name
        } else {
            return "\(self.file.package).\(self.name)"
        }
    }

    public func implementationName(using namer: SwiftProtobufNamer) -> String {
        let upperCamelName = NamingUtils.toUpperCamelCase(self.name) + "Client"
        if self.file.package.isEmpty {
            return upperCamelName
        } else {
            return namer.typePrefix(forFile: self.file) + upperCamelName
        }
    }

    public func protocolName(using namer: SwiftProtobufNamer) -> String {
        return self.implementationName(using: namer) + "Interface"
    }
}
