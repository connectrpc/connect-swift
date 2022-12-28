/// Interface for options that can be used to configure `ProtocolClientInterface` implementations.
/// External consumers can adopt this protocol to implement custom configurations.
public protocol ProtocolClientOption {
    /// Invoked by `ProtocolClientInterface` implementations allowing the option to mutate the
    /// configuration for the client.
    ///
    /// - parameter config: The current client configuration.
    ///
    /// - returns: The updated client configuration, with settings from this client option applied.
    func apply(_ config: ProtocolClientConfig) -> ProtocolClientConfig
}
