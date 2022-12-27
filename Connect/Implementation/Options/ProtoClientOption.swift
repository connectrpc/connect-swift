/// Enables Protobuf binary as the serialization method for requests/responses.
public struct ProtoClientOption {
    public init() {}
}

extension ProtoClientOption: ProtocolClientOption {
    public func apply(_ config: ProtocolClientConfig) -> ProtocolClientConfig {
        return config.clone(codec: ProtoCodec())
    }
}
