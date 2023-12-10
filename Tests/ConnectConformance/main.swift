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

import Connect
import ConnectNIO
import Foundation
import SwiftProtobuf

// MARK: - Main function

private let clientTypeArg = try ClientTypeArg.fromCommandLineArguments(CommandLine.arguments)
//private let encodingArg = try EncodingArg.fromCommandLineArguments(CommandLine.arguments)
private let request = try Connectrpc_Conformance_V1_ClientCompatRequest(
    serializedData: FileHandle.standardInput.readDataToEndOfFile()
)

guard request.service == "connectrpc.conformance.v1.ConformanceService" else {
    throw "Unexpected service specified: \(request.service)"
}

let protocolClient = try createProtocolClient()
let invoker = ConformanceInvoker(request: request, protocolClient: protocolClient)
let response: Connectrpc_Conformance_V1_ClientCompatResponse
do {
    let result = try await invoker.invokeRequest()
    response = .with { conformanceResponse in
        conformanceResponse.testName = request.testName
        conformanceResponse.response = result
    }
} catch let error {
    response = .with { conformanceResponse in
        conformanceResponse.testName = request.testName
        conformanceResponse.error = .with { conformanceError in
            conformanceError.message = error.localizedDescription
        }
    }
}

if #available(macOS 10.15.4, *) {
    try FileHandle.standardOutput.write(contentsOf: response.serializedData())
} else {
    throw "Unsupported version of macOS"
}

// MARK: - CLI arguments

private enum ClientTypeArg: String, CaseIterable, CommandLineArgument {
    case swiftNIO = "nio"
    case urlSession = "urlsession"

    static let key = "client"
}

//private enum EncodingArg: String, CaseIterable, CommandLineArgument {
//    case binary = "binary"
//    case json = "json"
//
//    static let key = "encoding"
//}

// MARK: - Helper functions

private func createProtocolClient() throws -> Connect.ProtocolClientInterface {
    return ProtocolClient(
        httpClient: createHTTPClient(),
        config: ProtocolClientConfig(
            host: "https://\(request.host)",
            networkProtocol: try createNetworkProtocol(),
            codec: try createCodec(),
            unaryGET: .alwaysEnabled,
            requestCompression: try createRequestCompression()
        )
    )
}

private func createHTTPClient() -> Connect.HTTPClientInterface {
    let timeout: TimeInterval = request.hasTimeoutMs ? Double(request.timeoutMs) / 1_000.0 : 60.0
    switch clientTypeArg {
    case .swiftNIO:
        return ConformanceNIOHTTPClient(
            host: "https://\(request.host)",
            port: Int(request.port),
            timeout: timeout
        )
    case .urlSession:
        return ConformanceURLSessionHTTPClient(
            timeout: timeout
        )
    }
}

private func createRequestCompression() throws -> Connect.ProtocolClientConfig.RequestCompression? {
    switch request.compression {
    case .identity, .unspecified:
        return nil
    case .gzip:
        return Connect.ProtocolClientConfig.RequestCompression(minBytes: 1, pool: GzipCompressionPool())
    case .br, .zstd, .deflate, .snappy, .UNRECOGNIZED:
        throw "Unexpected request compression specified: \(request.compression)"
    }
}

private func createCodec() throws -> Connect.Codec {
    switch request.codec {
    case .proto, .unspecified:
        return ProtoCodec()
    case .json:
        return JSONCodec()
    case .text, .UNRECOGNIZED:
        throw "Unexpected codec specified: \(request.codec)"
    }
}

private func createNetworkProtocol() throws -> Connect.NetworkProtocol {
    switch request.protocol {
    case .connect, .unspecified:
        return .connect
    case .grpc:
        return .grpc
    case .grpcWeb:
        return .grpcWeb
    case .UNRECOGNIZED:
        throw "Unexpected protocol specified: \(request.protocol)"
    }
}

extension String: Swift.Error {}
