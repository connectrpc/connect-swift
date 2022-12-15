/// Represents a chain of interceptors that is used for a single request/stream,
/// and orchestrates invoking each of them as needed.
struct InterceptorChain {
    private let interceptors: [Interceptor]

    init(
        interceptors: [(ProtocolClientConfig) -> Interceptor], config: ProtocolClientConfig
    ) {
        // Reverse the interceptor order up front to avoid reversing multiple times later.
        self.interceptors = interceptors
            .reversed()
            .map { initialize in initialize(config) }
    }

    func unaryFunction() -> UnaryFunction {
        let interceptors = self.interceptors.map { $0.unaryFunction() }
        return UnaryFunction(
            requestFunction: { request in
                return executeInterceptors(interceptors.map(\.requestFunction), initial: request)
            },
            responseFunction: { response in
                return executeInterceptors(interceptors.map(\.responseFunction), initial: response)
            }
        )
    }

    func streamFunction() -> StreamFunction {
        let interceptors = self.interceptors.map { $0.streamFunction() }
        return StreamFunction(
            requestFunction: { request in
                return executeInterceptors(interceptors.map(\.requestFunction), initial: request)
            },
            requestDataFunction: { data in
                return executeInterceptors(interceptors.map(\.requestDataFunction), initial: data)
            },
            streamResultFunc: { result in
                return executeInterceptors(interceptors.map(\.streamResultFunc), initial: result)
            }
        )
    }
}

private func executeInterceptors<T>(_ interceptors: [(T) -> T], initial: T) -> T {
    var next = initial
    for interceptor in interceptors {
        next = interceptor(next)
    }
    return next
}
