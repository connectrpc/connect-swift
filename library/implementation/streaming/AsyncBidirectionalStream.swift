import SwiftProtobuf

struct AsyncBidirectionalStream<Input: SwiftProtobuf.Message, Output: SwiftProtobuf.Message> {
    private let codec: Codec
    private let requestCallbacks: RequestCallbacks

    private var asyncStream: AsyncStream<StreamResult<Output>>!
    private var receiveResult: ((StreamResult<Output>) -> Void)!

    init(requestCallbacks: RequestCallbacks, codec: Codec) {
        self.codec = codec
        self.requestCallbacks = requestCallbacks
        
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
                requestCallbacks.sendClose()
            }
        }
    }

    func receive(_ result: StreamResult<Output>) {
        self.receiveResult(result)
    }

    @discardableResult
    func send(_ input: Input) throws -> Self {
        self.requestCallbacks.sendData(try self.codec.serialize(message: input))
        return self
    }

    func close() {
        self.requestCallbacks.sendClose()
    }
}
