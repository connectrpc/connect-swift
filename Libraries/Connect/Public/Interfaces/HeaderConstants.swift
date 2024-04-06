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

public enum HeaderConstants {
    public static let acceptEncoding = "accept-encoding"
    public static let contentEncoding = "content-encoding"
    public static let contentType = "content-type"

    public static let connectProtocolVersion = "connect-protocol-version"
    public static let connectTimeoutMs = "connect-timeout-ms"

    public static let connectStreamingAcceptEncoding = "connect-accept-encoding"
    public static let connectStreamingContentEncoding = "connect-content-encoding"

    public static let xUserAgent = "x-user-agent"

    public static let grpcAcceptEncoding = "grpc-accept-encoding"
    public static let grpcContentEncoding = "grpc-encoding"
    public static let grpcMessage = "grpc-message"
    public static let grpcStatus = "grpc-status"
    public static let grpcStatusDetails = "grpc-status-details-bin"
    public static let grpcTimeout = "grpc-timeout"
    public static let grpcTE = "te"
}
