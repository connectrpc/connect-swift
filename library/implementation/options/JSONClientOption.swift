/// Enables JSON as the encoding/decoding for requests/responses.
public struct JSONClientOption {
    public init() {}
}

extension JSONClientOption: ProtocolClientOption {
    public func apply(_ config: ProtocolClientConfig) -> ProtocolClientConfig {
        return config.clone(codec: JSONCodec())
    }
}
