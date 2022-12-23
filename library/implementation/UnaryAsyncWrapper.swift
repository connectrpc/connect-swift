import SwiftProtobuf

/// Internal actor used to wrap closure-based unary API calls in a way that allows them
/// to be used with async/await while properly supporting cancelation.
///
/// For discussions on why this is necessary, see:
/// https://forums.swift.org/t/how-to-use-withtaskcancellationhandler-properly/54341/37
/// https://stackoverflow.com/q/71898080
actor UnaryAsyncWrapper<Output: SwiftProtobuf.Message> {
    private var cancelable: Cancelable?
    private let sendUnary: PerformClosure

    /// Accepts a closure to be called upon completion of a request and returns a cancelable which,
    /// when invoked, will cancel the underlying request.
    typealias PerformClosure = (
        @escaping (ResponseMessage<Output>) -> Void
    ) -> Cancelable

    init(sendUnary: @escaping PerformClosure) {
        self.sendUnary = sendUnary
    }

    /// Provides an `async` interface for performing the `sendUnary` request.
    /// Canceling the request in the context of an async `Task` will appropriately cancel the
    /// outbound request and return a response with a `.canceled` status code.
    ///
    /// - returns: The response/result of the request.
    func send() async -> ResponseMessage<Output> {
        return await withTaskCancellationHandler(operation: {
            return await withCheckedContinuation { continuation in
                if Task.isCancelled {
                    continuation.resume(returning: .canceled())
                } else {
                    self.cancelable = self.sendUnary { response in
                        continuation.resume(returning: response)
                    }
                }
            }
        }, onCancel: {
            Task { await self.cancelable?.cancel() }
        })
    }
}

private extension ResponseMessage {
    static func canceled() -> Self {
        return .init(
            code: .canceled,
            headers: [:],
            message: nil,
            trailers: [:],
            error: .from(code: .canceled, headers: [:], source: nil)
        )
    }
}
