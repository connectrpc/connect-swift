import SwiftProtobuf

final class BidirectionalAsyncStream<Input: SwiftProtobuf.Message, Output: SwiftProtobuf.Message> {
    private var codec: Codec?
    private var requestCallbacks: RequestCallbacks?

    private var asyncStream: AsyncStream<StreamResult<Output>>!
    private var receiveResult: ((StreamResult<Output>) -> Void)!

    private struct NotConfiguredForSendingError: Swift.Error {}

    init() {
        self.asyncStream = AsyncStream<StreamResult<Output>> { continuation in
            self.receiveResult = { result in
                if Task.isCancelled {
                    return
                }
                switch result {
                case .headers, .message:
                    continuation.yield(result)
                case .complete:
                    continuation.yield(result)
                    continuation.finish()
                }
            }
            continuation.onTermination = { @Sendable _ in
                self.requestCallbacks?.sendClose()
            }
        }
    }

    func configureForSending(with codec: Codec, requestCallbacks: RequestCallbacks) {
        self.codec = codec
        self.requestCallbacks = requestCallbacks
    }

    func receive(_ result: StreamResult<Output>) {
        self.receiveResult(result)
    }
}

extension BidirectionalAsyncStream: BidirectionalAsyncStreamInterface {
    @discardableResult
    func send(_ input: Input) throws -> Self {
        guard let codec = self.codec, let sendData = self.requestCallbacks?.sendData else {
            throw NotConfiguredForSendingError()
        }

        sendData(try codec.serialize(message: input))
        return self
    }

    func results() -> AsyncStream<StreamResult<Output>> {
        return self.asyncStream
    }

    func close() {
        self.requestCallbacks?.sendClose()
    }
}
