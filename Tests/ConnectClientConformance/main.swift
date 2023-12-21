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

import Foundation
import SwiftProtobuf

// MARK: - Helpers

private let prefixLength = MemoryLayout<UInt32>.size // 4

private func nextMessageLength(using data: Data) -> Int {
    var messageLength: UInt32 = 0
    (data[0...3] as NSData).getBytes(&messageLength, length: prefixLength)
    messageLength = UInt32(bigEndian: messageLength)
    return Int(messageLength)
}

@available(macOS 10.15.4, *)
private func main() async throws {
    var number = 0
    while let lengthData = try FileHandle.standardInput.read(upToCount: prefixLength) {
        number += 1

        if lengthData.count != prefixLength {
            break
        }
//        FileHandle.standardOutput.write("\n\npreparing to read request \(number)\n".data(using: .utf8)!)

        let nextRequestLength = nextMessageLength(using: lengthData)
        guard let nextRequestData = try FileHandle.standardInput.read(upToCount: nextRequestLength) else {
            throw "Expected \(nextRequestLength) bytes to deserialize request"
        }

        // TODO: Run tests concurrently
        let request = try Connectrpc_Conformance_V1_ClientCompatRequest(serializedData: nextRequestData)
        let invoker = try ConformanceInvoker(request: request, clientType: clientTypeArg)
        let response: Connectrpc_Conformance_V1_ClientCompatResponse
        do {
            guard request.service == "connectrpc.conformance.v1.ConformanceService" else {
                throw "Unexpected service specified: \(request.service)"
            }

            let result = try await invoker.invokeRequest()
            response = .with { conformanceResponse in
                conformanceResponse.testName = request.testName
                conformanceResponse.response = result
            }
        } catch let error {
            // Unexpected local/runtime error (no RPC response).
            response = .with { conformanceResponse in
                conformanceResponse.testName = request.testName
                conformanceResponse.error = .with { conformanceError in
                    conformanceError.message = "\(error)"
                }
            }
        }

        let serializedResponse = try response.serializedData()
        var responseLength = UInt32(serializedResponse.count).bigEndian
        let output = Data(bytes: &responseLength, count: prefixLength) + serializedResponse
        FileHandle.standardOutput.write(output)
//        FileHandle.standardOutput.write("\n".data(using: .utf8)!)
    }
//    throw "DONE WITH LOOP"
}

extension String: Swift.Error {}

// MARK: - Main invocation

Google_Protobuf_Any.register(messageType: Connectrpc_Conformance_V1_BidiStreamRequest.self)
Google_Protobuf_Any.register(messageType: Connectrpc_Conformance_V1_ClientCompatResponse.self)
Google_Protobuf_Any.register(messageType: Connectrpc_Conformance_V1_ClientErrorResult.self)
Google_Protobuf_Any.register(messageType: Connectrpc_Conformance_V1_ClientResponseResult.self)
Google_Protobuf_Any.register(messageType: Connectrpc_Conformance_V1_ClientStreamRequest.self)
Google_Protobuf_Any.register(messageType: Connectrpc_Conformance_V1_ConformancePayload.self)
Google_Protobuf_Any.register(messageType: Connectrpc_Conformance_V1_Error.self)
Google_Protobuf_Any.register(messageType: Connectrpc_Conformance_V1_Header.self)
Google_Protobuf_Any.register(messageType: Connectrpc_Conformance_V1_ServerStreamRequest.self)
Google_Protobuf_Any.register(messageType: Connectrpc_Conformance_V1_UnaryRequest.self)

private let clientTypeArg = try ClientTypeArg.fromCommandLineArguments(CommandLine.arguments)

if #available(macOS 10.15.4, *) {
    try await main()
//    FileHandle.standardOutput.write("\n".data(using: .utf8)!)
    _ = try FileHandle.standardInput.readToEnd()
    fflush(stdout)
//    try FileHandle.standardOutput.close()
//    throw "Finished main"
    exit(EXIT_SUCCESS)
//    FileHandle.standardOutput.write("Data left: \(try FileHandle.standardInput.readToEnd()?.count ?? 0)".data(using: .utf8)!)
} else {
    throw "Unsupported version of macOS"
}
