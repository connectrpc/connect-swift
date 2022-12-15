/// Represents a chain of interceptors that is used for a single request/stream,
/// and orchestrates invoking each of them as needed.
struct InterceptorChain {
    private let interceptors: [Interceptor]

    init(
        interceptors: [(ProtocolClientConfig) -> Interceptor], config: ProtocolClientConfig
    ) {
        self.interceptors = interceptors.map { initialize in initialize(config) }
    }

    /// Create a set of closures configured with all interceptors for a unary API.
    ///
    /// NOTE: Interceptors are invoked in FIFO order for the request path, and in LIFO order for
    /// the response path. For example, with interceptors `[a, b, c]`:
    /// `caller -> a -> b -> c -> server`
    /// `caller <- c <- b <- a <- server`
    ///
    /// - returns: A set of closures that each invoke the chain of interceptors in the above order.
    func unaryFunction() -> UnaryFunction {
        let interceptors = self.interceptors.lazy.map { $0.unaryFunction() }
        return UnaryFunction(
            requestFunction: { request in
                return executeInterceptors(interceptors.map(\.requestFunction), initial: request)
            },
            responseFunction: { response in
                return executeInterceptors(
                    interceptors.reversed().map(\.responseFunction),
                    initial: response
                )
            }
        )
    }

    /// Create a set of closures configured with all interceptors for a stream.
    ///
    /// NOTE: Interceptors are invoked in FIFO order for the request path, and in LIFO order for
    /// the response path. For example, with interceptors `[a, b, c]`:
    /// `caller -> a -> b -> c -> server`
    /// `caller <- c <- b <- a <- server`
    ///
    /// - returns: A set of closures that each invoke the chain of interceptors in the above order.
    func streamFunction() -> StreamFunction {
        let interceptors = self.interceptors.lazy.map { $0.streamFunction() }
        return StreamFunction(
            requestFunction: { request in
                return executeInterceptors(interceptors.map(\.requestFunction), initial: request)
            },
            requestDataFunction: { data in
                return executeInterceptors(interceptors.map(\.requestDataFunction), initial: data)
            },
            streamResultFunc: { result in
                return executeInterceptors(
                    interceptors.reversed().map(\.streamResultFunc),
                    initial: result
                )
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
