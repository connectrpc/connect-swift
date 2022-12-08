import Foundation

/// Enables the client to speak using the gRPC Web protocol:
/// https://github.com/grpc/grpc/blob/master/doc/PROTOCOL-WEB.md
public struct GRPCWebClientOption {
    public init() {}
}

extension GRPCWebClientOption: ProtocolClientOption {
    public func apply(_ config: ProtocolClientConfig) -> ProtocolClientConfig {
        return config.clone(interceptors: [GRPCWebInterceptor.init] + config.interceptors)
    }
}

/// The gRPC Web protocol is implemented as an interceptor in the request/response chain.
private struct GRPCWebInterceptor {
    private let config: ProtocolClientConfig

    init(config: ProtocolClientConfig) {
        self.config = config
    }
}

extension GRPCWebInterceptor: Interceptor {
    func wrapUnary(nextUnary: UnaryFunction) -> UnaryFunction {
        return UnaryFunction(
            requestFunction: { request in
                // GRPC unary payloads are enveloped.
                let envelopedRequestBody = Envelope.packMessage(
                    request.message ?? Data(),
                    compressionPool: self.config.requestCompressionPool(),
                    compressionMinBytes: self.config.compressionMinBytes
                )

                return HTTPRequest(
                    target: request.target,
                    // Override the content type to be gRPC Web.
                    contentType: "application/grpc-web+\(self.config.codec.name())",
                    headers: request.headers.addingGRPCWebHeaders(using: self.config),
                    message: envelopedRequestBody
                )
            },
            responseFunction: { response in
                let compressionPool = response.headers[HeaderConstants.grpcContentEncoding]?
                    .first
                    .flatMap { self.config.compressionPools[$0] }
                do {
                    // gRPC Web returns data in 2 chunks (either/both of which may be compressed):
                    // 1. OPTIONAL (when not trailers-only): The (headers and length prefixed)
                    //    message data.
                    // 2. The (headers and length prefixed) trailers data.
                    // https://github.com/grpc/grpc/blob/master/doc/PROTOCOL-WEB.md
                    let responseData = response.message ?? Data()
                    let firstChunkLength = Envelope.messageLength(forPackedData: responseData)
                    let prefixedFirstChunkLength = Envelope.prefixLength + firstChunkLength
                    let firstChunk = try Envelope.unpackMessage(
                        Data(responseData.prefix(upTo: prefixedFirstChunkLength)),
                        compressionPool: compressionPool
                    )
                    let isTrailersOnly = 0b10000000 & firstChunk.headerByte != 0
                    if isTrailersOnly {
                        let unpackedTrailers = try Trailers.fromGRPCHeadersBlock(
                            firstChunk.unpacked
                        )
                        return response.withHandledGRPCWebTrailers(unpackedTrailers, message: nil)
                    } else {
                        let trailersData = Data(responseData.suffix(from: prefixedFirstChunkLength))
                        let unpackedTrailers = try Trailers.fromGRPCHeadersBlock(
                            try Envelope.unpackMessage(
                                trailersData, compressionPool: compressionPool
                            ).unpacked
                        )
                        return response.withHandledGRPCWebTrailers(
                            unpackedTrailers,
                            message: firstChunk.unpacked
                        )
                    }
                } catch let error {
                    return HTTPResponse(
                        code: .unknown,
                        headers: response.headers,
                        message: response.message,
                        trailers: nil,
                        error: error
                    )
                }
            }
        )
    }

    func wrapStream(nextStream: StreamingFunction) -> StreamingFunction {
        var responseCompressionPool: CompressionPool?
        return StreamingFunction(
            requestFunction: { request in
                return HTTPRequest(
                    target: request.target,
                    // Override the content type to be gRPC Web.
                    contentType: "application/grpc-web+\(self.config.codec.name())",
                    headers: request.headers.addingGRPCWebHeaders(using: self.config),
                    message: request.message
                )
            },
            requestDataFunction: { data in
                return Envelope.packMessage(
                    data,
                    compressionPool: self.config.requestCompressionPool(),
                    compressionMinBytes: self.config.compressionMinBytes
                )
            },
            streamResultFunc: { result in
                switch result {
                case .complete:
                    return result

                case .headers(let headers):
                    responseCompressionPool = headers[HeaderConstants.grpcContentEncoding]?
                        .first
                        .flatMap { self.config.compressionPools[$0] }
                    return result

                case .message(let data):
                    do {
                        let (headerByte, unpackedData) = try Envelope.unpackMessage(
                            data, compressionPool: responseCompressionPool
                        )
                        let isTrailers = 0b10000000 & headerByte != 0
                        if isTrailers {
                            let trailers = try Trailers.fromGRPCHeadersBlock(unpackedData)
                            let grpcCode = trailers.grpcStatus()
                            if grpcCode == .ok {
                                return .complete(error: nil, trailers: trailers)
                            } else {
                                return .complete(
                                    error: ConnectError.fromGRPCWebTrailers(
                                        trailers, code: grpcCode
                                    ),
                                    trailers: trailers
                                )
                            }
                        } else {
                            return .message(unpackedData)
                        }
                    } catch let error {
                        // TODO: Close the stream here?
                        return .complete(error: error, trailers: nil)
                    }
                }
            }
        )
    }
}

// MARK: - Private

private struct TrailersDecodingError: Error {}

private extension Headers {
    func addingGRPCWebHeaders(using config: ProtocolClientConfig) -> Self {
        var headers = self
        headers[HeaderConstants.grpcAcceptEncoding] = config
            .acceptCompressionPoolNames()
        headers[HeaderConstants.grpcContentEncoding] = config.requestCompressionPool()
            .map { [type(of: $0).name()] }
        headers[HeaderConstants.grpcTE] = ["trailers"]
        return headers
    }
}

private extension Trailers {
    static func fromGRPCHeadersBlock(_ source: Data) throws -> Self {
        guard let string = String(data: source, encoding: .utf8) else {
            throw TrailersDecodingError()
        }

        // Decode trailers based on gRPC Web spec:
        // https://github.com/grpc/grpc/blob/master/doc/PROTOCOL-WEB.md
        return string
            .split(separator: "\r\n")
            .reduce(into: Trailers()) { trailers, line in
                guard let separatorIndex = line.firstIndex(of: ":") else {
                    return
                }

                let trailerName = String(line.prefix(upTo: separatorIndex)).lowercased()
                var trailerValue = String(line.suffix(from: separatorIndex + 1))
                if trailerValue.hasPrefix(" ") {
                    trailerValue.removeFirst()
                }
                trailers[trailerName] = trailerValue
                    .split(separator: ",")
                    .map { String($0) }
            }
    }

    func grpcStatus() -> Code {
        return self[HeaderConstants.grpcStatus]?
            .first
            .flatMap(Int.init)
            .flatMap { Code(rawValue: $0) }
            ?? .unknown
    }

    func connectErrorDetails() -> [ConnectError.Detail] {
        return self[HeaderConstants.grpcStatusDetails]?
            .first
            .flatMap { Data(base64Encoded: $0) }
            .flatMap { data -> Grpc_Status_V1_Status? in
                return try? ProtoCodec().deserialize(source: data)
            }?
            .details
            .compactMap { protoDetail in
                return ConnectError.Detail(
                    type: protoDetail.typeURL,
                    payload: String(data: protoDetail.value, encoding: .utf8)
                )
            }
            ?? []
    }
}

private extension HTTPResponse {
    func withHandledGRPCWebTrailers(_ trailers: Trailers, message: Data?) -> Self {
        let grpcStatus = trailers.grpcStatus()
        if grpcStatus == .ok {
            return HTTPResponse(
                code: grpcStatus,
                headers: self.headers,
                message: message,
                trailers: trailers,
                error: nil
            )
        } else {
            return HTTPResponse(
                code: grpcStatus,
                headers: self.headers,
                message: message,
                trailers: trailers,
                error: ConnectError.fromGRPCWebTrailers(trailers, code: grpcStatus)
            )
        }
    }
}

private extension ConnectError {
    static func fromGRPCWebTrailers(_ trailers: Trailers, code: Code) -> Self {
        return ConnectError(
            code: code,
            message: trailers[HeaderConstants.grpcMessage]?.first,
            exception: nil,
            details: trailers.connectErrorDetails(),
            metadata: [:]
        )
    }
}
