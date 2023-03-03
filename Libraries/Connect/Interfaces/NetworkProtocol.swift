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

/// Protocols that are supported by the library.
public enum NetworkProtocol {
    /// The Connect protocol:
    /// https://connect.build/docs/protocol
    case connect
    /// The gRPC-Web protocol:
    /// https://github.com/grpc/grpc/blob/master/doc/PROTOCOL-WEB.md
    case grpcWeb
}