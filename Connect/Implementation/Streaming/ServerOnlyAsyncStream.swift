import SwiftProtobuf

/// Concrete implementation of `ServerOnlyAsyncStreamInterface`.
final class ServerOnlyAsyncStream<Input: SwiftProtobuf.Message, Output: SwiftProtobuf.Message> {
    private let bidirectionalStream: BidirectionalAsyncStream<Input, Output>

    init(bidirectionalStream: BidirectionalAsyncStream<Input, Output>) {
        self.bidirectionalStream = bidirectionalStream
    }
}

extension ServerOnlyAsyncStream: ServerOnlyAsyncStreamInterface {
    func send(_ input: Input) throws {
        try self.bidirectionalStream.send(input)
        self.bidirectionalStream.close()
    }

    func results() -> AsyncStream<StreamResult<Output>> {
        return self.bidirectionalStream.results()
    }
}
