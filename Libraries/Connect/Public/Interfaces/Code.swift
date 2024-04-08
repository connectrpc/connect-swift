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

/// Indicates a status of an RPC.
/// The zero code in gRPC is OK, which indicates that the operation was a success.
public enum Code: Int, CaseIterable, Equatable, Sendable {
    case ok = 0
    case canceled = 1
    case unknown = 2
    case invalidArgument = 3
    case deadlineExceeded = 4
    case notFound = 5
    case alreadyExists = 6
    case permissionDenied = 7
    case resourceExhausted = 8
    case failedPrecondition = 9
    case aborted = 10
    case outOfRange = 11
    case unimplemented = 12
    case internalError = 13
    case unavailable = 14
    case dataLoss = 15
    case unauthenticated = 16

    public var name: String {
        switch self {
        case .ok:
            return "ok"
        case .canceled:
            return "canceled"
        case .unknown:
            return "unknown"
        case .invalidArgument:
            return "invalid_argument"
        case .deadlineExceeded:
            return "deadline_exceeded"
        case .notFound:
            return "not_found"
        case .alreadyExists:
            return "already_exists"
        case .permissionDenied:
            return "permission_denied"
        case .resourceExhausted:
            return "resource_exhausted"
        case .failedPrecondition:
            return "failed_precondition"
        case .aborted:
            return "aborted"
        case .outOfRange:
            return "out_of_range"
        case .unimplemented:
            return "unimplemented"
        case .internalError:
            return "internal"
        case .unavailable:
            return "unavailable"
        case .dataLoss:
            return "data_loss"
        case .unauthenticated:
            return "unauthenticated"
        }
    }

    public static func fromHTTPStatus(_ status: Int) -> Self {
        // https://connectrpc.com/docs/protocol#http-to-error-code
        switch status {
        case 200:
            return .ok
        case 400:
            return .internalError
        case 401:
            return .unauthenticated
        case 403:
            return .permissionDenied
        case 404:
            return .unimplemented
        case 429, 502, 503, 504:
            return .unavailable
        default:
            return .unknown
        }
    }

    public static func fromName(_ name: String) -> Self? {
        return Self.allCases.first { $0.name == name }
    }
}
