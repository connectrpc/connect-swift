/// Provides an implementation of gzip for encoding/decoding.
public struct GzipCompressionOption {
    public init() {}
}

extension GzipCompressionOption: ProtocolClientOption {
    public func apply(_ config: ProtocolClientConfig) -> ProtocolClientConfig {
        var compressionPools = config.compressionPools
        compressionPools[GzipCompressionPool.name()] = GzipCompressionPool()
        return config.clone(compressionPools: compressionPools)
    }
}
