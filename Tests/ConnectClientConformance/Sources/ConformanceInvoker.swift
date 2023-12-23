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
    private let client: ConformanceClient
    private let request: ConformanceRequest

    typealias ConformanceClient = Connectrpc_Conformance_V1_ConformanceServiceClient
    typealias ConformanceRequest = Connectrpc_Conformance_V1_ClientCompatRequest
    typealias ConformanceResult = Connectrpc_Conformance_V1_ClientResponseResult

    // MARK: - Initialization

    init(request: ConformanceRequest, clientType: ClientTypeArg) throws {
        switch (request.protocol, clientType) {
        case (.grpc, .urlSession):
            throw "gRPC is not supported by URLSession"
        default:
            break
        }

        self.request = request
        self.client = try ConformanceClient(client: Self.protocolClient(for: request, clientType: clientType))
    }

    private static func protocolClient(
        for request: ConformanceRequest, clientType: ClientTypeArg
    ) throws -> ProtocolClientInterface {
        return ProtocolClient(
            httpClient: self.httpClient(for: request, clientType: clientType),
            config: ProtocolClientConfig(
                host: "http://\(request.host):\(request.port)",
                networkProtocol: try self.networkProtocol(for: request),
                codec: try self.codec(for: request),
                unaryGET: .alwaysEnabled,
                requestCompression: try self.requestCompression(for: request)
            )
        )
    }

    private static func httpClient(
        for request: ConformanceRequest, clientType: ClientTypeArg
    ) -> HTTPClientInterface {
        let timeout: TimeInterval = request.hasTimeoutMs ? Double(request.timeoutMs) / 1_000.0 : 60.0
        switch clientType {
        case .swiftNIO:
            return ConformanceNIOHTTPClient(
                host: "http://\(request.host)",
                port: Int(request.port),
                timeout: timeout
            )
        case .urlSession:
            return ConformanceURLSessionHTTPClient(
                timeout: timeout
            )
        }
    }

    private static func requestCompression(
        for request: ConformanceRequest
    ) throws -> ProtocolClientConfig.RequestCompression? {
        switch request.compression {
        case .identity, .unspecified:
            return nil
        case .gzip:
            return Connect.ProtocolClientConfig.RequestCompression(minBytes: 0, pool: GzipCompressionPool())
        case .br, .zstd, .deflate, .snappy, .UNRECOGNIZED:
            throw "Unexpected request compression specified: \(request.compression)"
        }
    }

    private static func codec(for request: ConformanceRequest) throws -> Codec {
        switch request.codec {
        case .proto, .unspecified:
            return ProtoCodec()
        case .json:
            return JSONCodec()
        case .text, .UNRECOGNIZED:
            throw "Unexpected codec specified: \(request.codec)"
        }
    }

    private static func networkProtocol(for request: ConformanceRequest) throws -> NetworkProtocol {
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

    // MARK: - Invocation

    func invokeRequest() async throws -> ConformanceResult {
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

    private func invokeUnary() async throws -> ConformanceResult {
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

    private func invokeIdempotentUnary() async throws -> ConformanceResult {
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

    private func invokeServerStream() async throws -> ConformanceResult {
        let streamRequest = try Connectrpc_Conformance_V1_ServerStreamRequest(
            unpackingAny: self.request.requestMessages[0]
        )
        let stream = self.client.serverStream(headers: .fromConformanceHeaders(self.request.requestHeaders))
        try stream.send(streamRequest)

        var cancelAfterResponses = -1
        switch self.request.cancel.cancelTiming {
        case .beforeCloseSend:
            break // Does not apply to server-only streams.
        case .afterCloseSendMs(let milliseconds):
            DispatchQueue.global().asyncAfter(deadline: .now() + .milliseconds(Int(milliseconds))) {
                stream.cancel()
            }
        case .afterNumResponses(let responsesToReceive):
            cancelAfterResponses = Int(responsesToReceive)
        case .none:
            break
        }

        if cancelAfterResponses == 0 {
            stream.cancel()
        }

        var conformanceResult = ConformanceResult()
        for await result in stream.results() {
            switch result {
            case .headers(let headers):
                conformanceResult.responseHeaders = headers.toConformanceHeaders()
            case .message(let message):
                conformanceResult.payloads.append(message.payload)
                cancelAfterResponses -= 1
                if cancelAfterResponses == 0 {
                    stream.cancel()
                }
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

    private func invokeClientStream() async throws -> ConformanceResult {
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
        switch self.request.cancel.cancelTiming {
        case .beforeCloseSend:
            stream.cancel()
        case .afterCloseSendMs(let milliseconds):
            DispatchQueue.global().asyncAfter(deadline: .now() + .milliseconds(Int(milliseconds))) {
                stream.cancel()
            }
        case .afterNumResponses: // Does not apply to client-only streams.
            stream.close()
        case .none:
            stream.close()
        }

        var conformanceResult = ConformanceResult()
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

    private func invokeBidirectionalStream() async throws -> ConformanceResult {
        let stream = self.client.bidiStream(headers: .fromConformanceHeaders(self.request.requestHeaders))
        let asyncResults = stream.results()
        var cancelAfterResponses = -1
        var conformanceResult = ConformanceResult()
        func receive(upTo count: Int) async {
            for await result in asyncResults.prefix(count) {
                switch result {
                case .headers(let headers):
                    conformanceResult.responseHeaders = headers.toConformanceHeaders()
                case .message(let message):
                    conformanceResult.payloads.append(message.payload)
                    cancelAfterResponses -= 1
                    if cancelAfterResponses == 0 {
                        stream.cancel()
                    }
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

        switch self.request.cancel.cancelTiming {
        case .beforeCloseSend:
            stream.cancel()
        case .afterCloseSendMs(let milliseconds):
            DispatchQueue.global().asyncAfter(deadline: .now() + .milliseconds(Int(milliseconds))) {
                stream.cancel()
            }
        case .afterNumResponses(let responsesToReceive):
            cancelAfterResponses = Int(responsesToReceive)
        case .none:
            break
        }

        if cancelAfterResponses == 0 {
            stream.cancel()
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

        if case .beforeCloseSend = self.request.cancel.cancelTiming {
            stream.cancel()
        } else {
            stream.close()
        }

        // Receive any remaining responses.
        await receive(upTo: .max)
        return conformanceResult
    }

    private func invokeUnimplemented() async throws -> ConformanceResult {
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
