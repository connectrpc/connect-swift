/// Provides an implementation of gzip for encoding/decoding, allowing the client to compress
/// and decompress requests/responses using gzip.
///
/// To compress outbound requests, specify the `GzipRequestOption`.
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
