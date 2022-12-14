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
}

extension InterceptorChain: Interceptor {
    func wrapUnary(nextUnary: UnaryFunction) -> UnaryFunction {
        if self.interceptors.isEmpty {
            return nextUnary
        }

        var nextCall = nextUnary
        for interceptor in self.interceptors {
            nextCall = interceptor.wrapUnary(nextUnary: nextCall)
        }

        return nextCall
    }

    func wrapStream(nextStream: StreamingFunction) -> StreamingFunction {
        if self.interceptors.isEmpty {
            return nextStream
        }

        var nextCall = nextStream
        for interceptor in self.interceptors {
            nextCall = interceptor.wrapStream(nextStream: nextCall)
        }

        return nextCall
    }
}
