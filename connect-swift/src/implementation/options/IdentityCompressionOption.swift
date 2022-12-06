/// Provides a no-op default implementation for encoding/decoding.
public struct IdentityCompressionOption {
    public init() {}
}

extension IdentityCompressionOption: ProtocolClientOption {
    public func apply(_ config: ProtocolClientConfig) -> ProtocolClientConfig {
        var compressionPools = config.compressionPools
        compressionPools[IdentityCompressionPool.name()] = IdentityCompressionPool()
        return config.clone(compressionPools: compressionPools)
    }
}
