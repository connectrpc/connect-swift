/// Interface for an option that can be used to configure a `ProtocolClient`.
/// External consumers can adopt this protocol to implement custom configurations.
public protocol ProtocolClientOption {
    func apply(_ config: ProtocolClientConfig) -> ProtocolClientConfig
}
