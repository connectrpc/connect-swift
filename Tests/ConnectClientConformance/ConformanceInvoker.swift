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
import Foundation
import SwiftProtobuf

final class ConformanceInvoker {
    private let request: Connectrpc_Conformance_V1_ClientCompatRequest
    private let client: Connectrpc_Conformance_V1_ConformanceServiceClient

    init(
        request: Connectrpc_Conformance_V1_ClientCompatRequest,
        protocolClient: Connect.ProtocolClientInterface
    ) {
        self.request = request
        self.client = Connectrpc_Conformance_V1_ConformanceServiceClient(client: protocolClient)
    }

    func invokeRequest() async throws -> Connectrpc_Conformance_V1_ClientResponseResult {
        switch self.request.method {
        case "Unary":
            guard self.request.requestMessages.count == 1 else {
                throw "Unary calls must specify exactly one request message"
            }
            return try await self.invokeUnary()

        case "IdempotentUnary":
            guard self.request.requestMessages.count == 1 else {
                throw "Unary calls must specify exactly one request message"
            }
            return try await self.invokeIdempotentUnary()

        case "ServerStream":
            guard self.request.requestMessages.count == 1 else {
                throw "Server streaming calls must specify exactly one request message"
            }
            return try await self.invokeServerStream()

        case "ClientStream":
            return try await self.invokeClientStream()

        case "BidiStream":
            return try await self.invokeBidirectionalStream()

        case "Unimplemented":
            guard self.request.requestMessages.count == 1 else {
                throw "Unimplemented calls must specify exactly one request message"
            }
            return try await self.invokeUnimplemented()

        default:
            throw "Unexpected RPC method: \(self.request.method)"
        }
    }

    private func invokeUnary() async throws -> Connectrpc_Conformance_V1_ClientResponseResult {
        let unaryRequest = try Connectrpc_Conformance_V1_UnaryRequest(
            unpackingAny: self.request.requestMessages[0]
        )
        let response = await self.client.unary(
            request: unaryRequest,
            headers: .fromConformanceHeaders(self.request.requestHeaders)
        )
        if let error = response.error {
            return .with { responseResult in
                responseResult.responseHeaders = error.metadata.toConformanceHeaders()
                responseResult.error = error.toConformanceError()
            }
        } else {
            return .with { responseResult in
                responseResult.responseHeaders = response.headers.toConformanceHeaders()
                responseResult.responseTrailers = response.trailers.toConformanceHeaders()
                if response.message?.hasPayload == true, let payload = response.message?.payload {
                    responseResult.payloads = [payload]
                }
            }
        }
    }

    private func invokeIdempotentUnary() async throws -> Connectrpc_Conformance_V1_ClientResponseResult {
        let unaryRequest = try Connectrpc_Conformance_V1_IdempotentUnaryRequest(
            unpackingAny: self.request.requestMessages[0]
        )
        let response = await self.client.idempotentUnary(
            request: unaryRequest,
            headers: .fromConformanceHeaders(self.request.requestHeaders)
        )
        if let error = response.error {
            return .with { responseResult in
                responseResult.responseHeaders = error.metadata.toConformanceHeaders()
                responseResult.error = error.toConformanceError()
            }
        } else {
            return .with { responseResult in
                responseResult.responseHeaders = response.headers.toConformanceHeaders()
                responseResult.responseTrailers = response.trailers.toConformanceHeaders()
                if response.message?.hasPayload == true, let payload = response.message?.payload {
                    responseResult.payloads = [payload]
                }
            }
        }
    }

    private func invokeServerStream() async throws -> Connectrpc_Conformance_V1_ClientResponseResult {
        let streamRequest = try Connectrpc_Conformance_V1_ServerStreamRequest(
            unpackingAny: self.request.requestMessages[0]
        )
        let stream = self.client.serverStream(headers: .fromConformanceHeaders(self.request.requestHeaders))
        try stream.send(streamRequest)

        var conformanceResult = Connectrpc_Conformance_V1_ClientResponseResult()
        for await result in stream.results() {
            switch result {
            case .headers(let headers):
                conformanceResult.responseHeaders = headers.toConformanceHeaders()
            case .message(let message):
                conformanceResult.payloads.append(message.payload)
            case .complete(_, let error, let trailers):
                conformanceResult.responseTrailers = trailers?.toConformanceHeaders() ?? .init()
                if let connectError = error as? ConnectError {
                    conformanceResult.error = connectError.toConformanceError()
                } else if let error = error as NSError? {
                    conformanceResult.error = .with { conformanceError in
                        conformanceError.code = Int32(error.code)
                        conformanceError.message = error.localizedDescription
                    }
                }
            }
        }
        return conformanceResult
    }

    private func invokeClientStream() async throws -> Connectrpc_Conformance_V1_ClientResponseResult {
        let stream = self.client.clientStream(headers: .fromConformanceHeaders(self.request.requestHeaders))
        for requestMessage in self.request.requestMessages {
            let streamRequest = try Connectrpc_Conformance_V1_ClientStreamRequest(
                unpackingAny: requestMessage
            )
            if #available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *), self.request.requestDelayMs > 0 {
                try await Task.sleep(for: .milliseconds(self.request.requestDelayMs))
            }
            try stream.send(streamRequest)
        }
        stream.close()

        var conformanceResult = Connectrpc_Conformance_V1_ClientResponseResult()
        for await result in stream.results() {
            switch result {
            case .headers(let headers):
                conformanceResult.responseHeaders = headers.toConformanceHeaders()
            case .message(let message):
                conformanceResult.payloads.append(message.payload)
            case .complete(_, let error, let trailers):
                conformanceResult.responseTrailers = trailers?.toConformanceHeaders() ?? .init()
                if let connectError = error as? ConnectError {
                    conformanceResult.error = connectError.toConformanceError()
                } else if let error = error as NSError? {
                    conformanceResult.error = .with { conformanceError in
                        conformanceError.code = Int32(error.code)
                        conformanceError.message = error.localizedDescription
                    }
                }
            }
        }
        return conformanceResult
    }

    private func invokeBidirectionalStream() async throws -> Connectrpc_Conformance_V1_ClientResponseResult {
        let stream = self.client.bidiStream(headers: .fromConformanceHeaders(self.request.requestHeaders))
        let asyncResults = stream.results()
        var conformanceResult = Connectrpc_Conformance_V1_ClientResponseResult()
        func receive(upTo count: Int) async {
            for await result in asyncResults.prefix(count) {
                switch result {
                case .headers(let headers):
                    conformanceResult.responseHeaders = headers.toConformanceHeaders()
                case .message(let message):
                    conformanceResult.payloads.append(message.payload)
                case .complete(_, let error, let trailers):
                    conformanceResult.responseTrailers = trailers?.toConformanceHeaders() ?? .init()
                    if let connectError = error as? ConnectError {
                        conformanceResult.error = connectError.toConformanceError()
                    } else if let error = error as NSError? {
                        conformanceResult.error = .with { conformanceError in
                            conformanceError.code = Int32(error.code)
                            conformanceError.message = error.localizedDescription
                        }
                    }
                }
            }
        }

        for requestMessage in self.request.requestMessages {
            let streamRequest = try Connectrpc_Conformance_V1_BidiStreamRequest(
                unpackingAny: requestMessage
            )
            if #available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *), self.request.requestDelayMs > 0 {
                try await Task.sleep(for: .milliseconds(self.request.requestDelayMs))
            }
            try stream.send(streamRequest)

            if self.request.streamType == .fullDuplexBidiStream {
                // Receive after sending each request message.
                await receive(upTo: 1)
            }
        }
        stream.close()

        // Receive any remaining responses.
        await receive(upTo: .max)
        return conformanceResult
    }

    private func invokeUnimplemented() async throws -> Connectrpc_Conformance_V1_ClientResponseResult {
        let unimplementedRequest = try Connectrpc_Conformance_V1_UnimplementedRequest(
            unpackingAny: self.request.requestMessages[0]
        )
        let response = await self.client.unimplemented(
            request: unimplementedRequest,
            headers: .fromConformanceHeaders(self.request.requestHeaders)
        )
        if let error = response.error {
            return .with { responseResult in
                responseResult.responseHeaders = error.metadata.toConformanceHeaders()
                responseResult.error = error.toConformanceError()
            }
        } else {
            return .init()
        }
    }
}

private extension Connect.Headers {
    static func fromConformanceHeaders(_ conformanceHeaders: [Connectrpc_Conformance_V1_Header]) -> Self {
        return conformanceHeaders.reduce(into: Headers()) { partialResult, conformanceHeader in
            partialResult[conformanceHeader.name] = conformanceHeader.value
        }
    }

    func toConformanceHeaders() -> [Connectrpc_Conformance_V1_Header] {
        return self.reduce(into: [Connectrpc_Conformance_V1_Header]()) { partialResult, header in
            partialResult.append(.with { conformanceHeader in
                conformanceHeader.name = header.key
                conformanceHeader.value = header.value
            })
        }
    }
}

private extension Connect.ConnectError {
    func toConformanceError() -> Connectrpc_Conformance_V1_Error {
        return .with { conformanceError in
            conformanceError.code = Int32(self.code.rawValue)
            conformanceError.message = self.message ?? ""
            for detail in self.details {
                guard let payload = detail.payload else {
                    continue
                }

                conformanceError.details.append(.with { anyMessage in
                    anyMessage.typeURL = "\(SwiftProtobuf.defaultAnyTypeURLPrefix)/\(detail.type)"
                    anyMessage.value = payload
                })
            }
        }
    }
}