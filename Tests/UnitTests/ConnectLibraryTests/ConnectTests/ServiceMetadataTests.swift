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
import XCTest

final class ServiceMetadataTests: XCTestCase {
    func testMethodSpecsAreGeneratedCorrectlyForService() {
        XCTAssertEqual(
            Connectrpc_Conformance_V1_ConformanceServiceClient.Metadata.Methods.unary,
            MethodSpec(
                name: "Unary",
                service: "connectrpc.conformance.v1.ConformanceService",
                type: .unary
            )
        )
        XCTAssertEqual(
            Connectrpc_Conformance_V1_ConformanceServiceClient.Metadata.Methods.unary.path,
            "connectrpc.conformance.v1.ConformanceService/Unary"
        )

        XCTAssertEqual(
            Connectrpc_Conformance_V1_ConformanceServiceClient.Metadata.Methods.serverStream,
            MethodSpec(
                name: "ServerStream",
                service: "connectrpc.conformance.v1.ConformanceService",
                type: .serverStream
            )
        )
        XCTAssertEqual(
            Connectrpc_Conformance_V1_ConformanceServiceClient.Metadata.Methods.serverStream.path,
            "connectrpc.conformance.v1.ConformanceService/ServerStream"
        )

        XCTAssertEqual(
            Connectrpc_Conformance_V1_ConformanceServiceClient.Metadata.Methods.clientStream,
            MethodSpec(
                name: "ClientStream",
                service: "connectrpc.conformance.v1.ConformanceService",
                type: .clientStream
            )
        )
        XCTAssertEqual(
            Connectrpc_Conformance_V1_ConformanceServiceClient.Metadata.Methods.clientStream.path,
            "connectrpc.conformance.v1.ConformanceService/ClientStream"
        )

        XCTAssertEqual(
            Connectrpc_Conformance_V1_ConformanceServiceClient.Metadata.Methods.bidiStream,
            MethodSpec(
                name: "BidiStream",
                service: "connectrpc.conformance.v1.ConformanceService",
                type: .bidirectionalStream
            )
        )
        XCTAssertEqual(
            Connectrpc_Conformance_V1_ConformanceServiceClient.Metadata.Methods.bidiStream.path,
            "connectrpc.conformance.v1.ConformanceService/BidiStream"
        )
    }
}
