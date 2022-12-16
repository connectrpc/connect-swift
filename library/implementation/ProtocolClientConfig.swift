import Foundation

/// Set of configuration (usually modified through `ClientOption` types) used to set up clients.
public struct ProtocolClientConfig {
    /// The target host (e.g., https://buf.build).
    public let target: String
    public let httpClient: HTTPClientInterface
    public let compressionMinBytes: Int?
    public let compressionName: String?
    public let codec: Codec
    public let interceptors: [(ProtocolClientConfig) -> Interceptor]
    public let compressionPools: [String: CompressionPool]

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

    func createInterceptorChain() -> InterceptorChain {
        return InterceptorChain(interceptors: self.interceptors, config: self)
    }
}
