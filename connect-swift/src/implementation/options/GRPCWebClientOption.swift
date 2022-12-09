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
                guard let responseData = response.message, !responseData.isEmpty else {
                    let code = response.headers.grpcStatus()
                    return HTTPResponse(
                        code: code,
                        headers: response.headers,
                        message: response.message,
                        trailers: response.trailers,
                        error: response.error ?? ConnectError.fromGRPCWebTrailers(
                            response.headers, code: code
                        )
                    )
                }

                let compressionPool = response.headers[HeaderConstants.grpcContentEncoding]?
                    .first
                    .flatMap { self.config.compressionPools[$0] }
                do {
                    // gRPC Web returns data in 2 chunks (either/both of which may be compressed):
                    // 1. OPTIONAL (when not trailers-only): The (headers and length prefixed)
                    //    message data.
                    // 2. The (headers and length prefixed) trailers data.
                    // https://github.com/grpc/grpc/blob/master/doc/PROTOCOL-WEB.md
                    let firstChunkLength = Envelope.messageLength(forPackedData: responseData)
                    let prefixedFirstChunkLength = Envelope.prefixLength + firstChunkLength
                    let firstChunk = try Envelope.unpackMessage(
                        Data(responseData.prefix(upTo: prefixedFirstChunkLength)),
                        compressionPool: compressionPool
                    )
                    let isTrailersOnly = 0b10000000 & firstChunk.headerByte != 0
                    if isTrailersOnly {
                        let unpackedTrailers = try Trailers.fromGRPCHeadersDataBlock(
                            firstChunk.unpacked
                        )
                        return response.withHandledGRPCWebTrailers(unpackedTrailers, message: nil)
                    } else {
                        let trailersData = Data(responseData.suffix(from: prefixedFirstChunkLength))
                        let unpackedTrailers = try Trailers.fromGRPCHeadersDataBlock(
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
                        trailers: response.trailers,
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
                            let trailers = try Trailers.fromGRPCHeadersDataBlock(unpackedData)
                            let grpcCode = trailers.grpcStatus()
                            if grpcCode == .ok {
                                return .complete(code: .ok, error: nil, trailers: trailers)
                            } else {
                                return .complete(
                                    code: grpcCode,
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
                        return .complete(code: .unknown, error: error, trailers: nil)
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
    static func fromGRPCHeadersDataBlock(_ source: Data) throws -> Self {
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

    func grpcMessage() -> String? {
        return self[HeaderConstants.grpcMessage]?.first?.grpcPercentDecoded()
    }

    func connectErrorDetailsFromGRPCWeb() -> [ConnectError.Detail] {
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
                    payload: protoDetail.value
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
    static func fromGRPCWebTrailers(_ trailers: Trailers, code: Code) -> Self? {
        if code == .ok {
            return nil
        }

        return ConnectError(
            code: code,
            message: trailers.grpcMessage(),
            exception: nil,
            details: trailers.connectErrorDetailsFromGRPCWeb(),
            metadata: [:]
        )
    }
}

private extension String {
    /// grpcPercentEncode/grpcPercentDecode follows RFC 3986 Section 2.1 and the gRPC HTTP/2 spec.
    /// It's a variant of URL-encoding with fewer reserved characters. It's intended
    /// to take UTF-8 encoded text and escape non-ASCII bytes so that they're valid
    /// HTTP/1 headers, while still maximizing readability of the data on the wire.
    ///
    /// The grpc-message trailer (used for human-readable error messages) should be
    /// percent-encoded.
    ///
    /// References:
    ///
    ///    https://github.com/grpc/grpc/blob/master/doc/PROTOCOL-HTTP2.md#responses
    ///    https://datatracker.ietf.org/doc/html/rfc3986#section-2.1
    ///
    /// - returns: A decoded string using the above format.
    func grpcPercentDecoded() -> Self {
        let utf8 = self.utf8
        let endIndex = utf8.endIndex
        var characters = [UInt8]()
        let utf8Percent = UInt8(ascii: "%")
        var index = utf8.startIndex

        while index < endIndex {
            let character = utf8[index]
            if character == utf8Percent {
                let secondIndex = utf8.index(index, offsetBy: 2)
                if secondIndex >= endIndex {
                    return self // Decoding failed
                }

                if let decoded = String(
                    utf8[utf8.index(index, offsetBy: 1) ... secondIndex]
                ).flatMap({ UInt8($0, radix: 16) }) {
                    characters.append(decoded)
                    index = utf8.index(after: secondIndex)
                } else {
                    return self // Decoding failed
                }
            } else {
                characters.append(character)
                index = utf8.index(after: index)
            }
        }

        return String(decoding: characters, as: Unicode.UTF8.self)
    }
}
