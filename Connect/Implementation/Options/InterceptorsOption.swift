/// Adds interceptors to requests/responses.
///
/// If multiple `InterceptorsOption` instances are specified, the interceptors from each will
/// be added in the order specified.
public struct InterceptorsOption {
    private let interceptors: [(ProtocolClientConfig) -> Interceptor]

    public init(interceptors: [(ProtocolClientConfig) -> Interceptor]) {
        self.interceptors = interceptors
    }
}

extension InterceptorsOption: ProtocolClientOption {
    public func apply(_ config: ProtocolClientConfig) -> ProtocolClientConfig {
        return config.clone(interceptors: config.interceptors + self.interceptors)
    }
}
