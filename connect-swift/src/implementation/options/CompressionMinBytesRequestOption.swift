/// Requires a minimum payload size (in bytes) for a request to be compressed.
public struct CompressionMinBytesRequestOption {
    private let compressionMinBytes: Int

    public init(compressionMinBytes: Int) {
        self.compressionMinBytes = compressionMinBytes
    }
}

extension CompressionMinBytesRequestOption: ProtocolClientOption {
    public func apply(_ config: ProtocolClientConfig) -> ProtocolClientConfig {
        return config.clone(compressionMinBytes: self.compressionMinBytes)
    }
}
