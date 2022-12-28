/// Enables gzip compression on outbound requests using a compression pool registered for "gzip"
/// (i.e., the one provided by `GzipCompressionOption`).
///
/// If present, `ProtocolClientInterface` implementations should respect the
/// `ProtocolClientConfig.compressionMinBytes` configuration when compressing.
public struct GzipRequestOption {
    private let compressionMinBytes: Int

    /// Designated initializer.
    ///
    /// - parameter compressionMinBytes: If a request message payload exceeds this number of bytes,
    ///                                  the payload will be compressed. Smaller payload messages
    ///                                  will not be compressed.
    public init(compressionMinBytes: Int) {
        self.compressionMinBytes = compressionMinBytes
    }
}

extension GzipRequestOption: ProtocolClientOption {
    public func apply(_ config: ProtocolClientConfig) -> ProtocolClientConfig {
        return config.clone(
            compressionMinBytes: self.compressionMinBytes,
            compressionName: GzipCompressionPool.name()
        )
    }
}
