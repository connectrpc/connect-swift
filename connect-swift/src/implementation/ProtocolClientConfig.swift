import Foundation

/// Set of configuration (usually modified through `ClientOption` types) used to set up clients.
public struct ProtocolClientConfig {
    /// The target host (e.g., https://buf.build).
    let target: String
    let httpClient: HTTPClientInterface
    let compressionMinBytes: Int?
    let compressionName: String?
    let codec: Codec
    let interceptors: [(ProtocolClientConfig) -> Interceptor]
    let compressionPools: [String: CompressionPool]

    public func clone(
        compressionMinBytes: Int? = nil,
        compressionName: String? = nil,
        codec: Codec? = nil,
        interceptors: [(ProtocolClientConfig) -> Interceptor]? = nil,
        compressionPools: [String: CompressionPool]? = nil
    ) -> Self {
        return .init(
            target: self.target,
            httpClient: self.httpClient,
            compressionMinBytes: compressionMinBytes ?? self.compressionMinBytes,
            compressionName: compressionName ?? self.compressionName,
            codec: codec ?? self.codec,
            interceptors: interceptors ?? self.interceptors,
            compressionPools: compressionPools ?? self.compressionPools
        )
    }
}

extension ProtocolClientConfig {
    init(target: String, httpClient: HTTPClientInterface, codec: Codec) {
        self.target = target
        self.httpClient = httpClient
        self.compressionMinBytes = nil
        self.compressionName = nil
        self.codec = codec
        self.interceptors = []
        self.compressionPools = [:]
    }

    func requestCompressionPool() -> CompressionPool? {
        return self.compressionName.flatMap { self.compressionPools[$0] }
    }

    func acceptCompressionPoolNames() -> [String] {
        return self.compressionPools.keys.filter { $0 != IdentityCompressionPool.name() }
    }

    func createUnaryInterceptorChain() -> UnaryFunction {
        return InterceptorChain(interceptors: self.interceptors, config: self)
            .wrapUnary(nextUnary: .identity())
    }

    func createStreamingInterceptorChain() -> StreamingFunction {
        return InterceptorChain(interceptors: self.interceptors, config: self)
            .wrapStream(nextStream: .identity())
    }
}
