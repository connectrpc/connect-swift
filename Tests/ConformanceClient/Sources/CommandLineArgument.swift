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

// MARK: - Arguments

enum ClientTypeArg: String, CaseIterable, CommandLineArgument {
    case swiftNIO = "nio"
    case urlSession = "urlsession"

    static let key = "httpclient"
}

// MARK: - Protocol interface

protocol CommandLineArgument: RawRepresentable, CaseIterable {
    static var key: String { get }

    static func fromCommandLineArguments(_ arguments: [String]) throws -> Self
}

extension CommandLineArgument where RawValue == String {
    static func fromCommandLineArguments(_ arguments: [String]) throws -> Self {
        guard let argument = arguments.first(where: { $0.hasPrefix(self.key) }) else {
            throw "'\(self.key)' argument must be specified"
        }

        guard let argumentValue = self.init(
            rawValue: argument
                .replacingOccurrences(of: "\(self.key)=", with: "")
                .trimmingCharacters(in: .whitespaces)
        ) else {
            throw """
            Invalid argument passed for '\(self.key)' argument. \
            Expected \(self.allCases.map(\.rawValue)), got '\(argument)'
            """
        }

        return argumentValue
    }
}
