/// Represents a chain of interceptors that is used for a single request.
/// Matches the Go implementation in that the chain itself is represented as an interceptor
/// that invokes other interceptors:
/// https://github.com/bufbuild/connect-go/blob/main/interceptor.go
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

    func wrapUnary() -> UnaryFunction {
        let interceptors = self.interceptors.map { $0.wrapUnary() }
        return UnaryFunction(
            requestFunction: { request in
                return executeInterceptors(interceptors.map(\.requestFunction), initial: request)
            },
            responseFunction: { response in
                return executeInterceptors(interceptors.map(\.responseFunction), initial: response)
            }
        )
    }

    func wrapStream() -> StreamingFunction {
        let interceptors = self.interceptors.map { $0.wrapStream() }
        return StreamingFunction(
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
