/// Enables gzip compression on outbound requests.
public struct GzipRequestOption {
    public init() {}
}

extension GzipRequestOption: ProtocolClientOption {
    public func apply(_ config: ProtocolClientConfig) -> ProtocolClientConfig {
        return config.clone(compressionName: GzipCompressionPool.name())
    }
}
