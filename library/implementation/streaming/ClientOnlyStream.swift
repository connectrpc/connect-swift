import SwiftProtobuf

/// Concrete implementation of `ClientOnlyStream`.
final class ClientOnlyStream<Message: SwiftProtobuf.Message> {
    private let bidirectionalStream: BidirectionalStream<Message>

    init(bidirectionalStream: BidirectionalStream<Message>) {
        self.bidirectionalStream = bidirectionalStream
    }
}

extension ClientOnlyStream: ClientOnlyStreamInterface {
    typealias Input = Message

    @discardableResult
    func send(_ input: Message) throws -> Self {
        try self.bidirectionalStream.send(input)
        return self
    }

    func close() {
        self.bidirectionalStream.close()
    }
}
