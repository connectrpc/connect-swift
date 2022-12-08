import SwiftProtobuf

/// Concrete implementation of `ServerOnlyStreamInterface`.
final class ServerOnlyStream<Message: SwiftProtobuf.Message> {
    private let bidirectionalStream: BidirectionalStream<Message>

    init(bidirectionalStream: BidirectionalStream<Message>) {
        self.bidirectionalStream = bidirectionalStream
    }
}

extension ServerOnlyStream: ServerOnlyStreamInterface {
    typealias Input = Message

    func send(_ input: Message) throws {
        try self.bidirectionalStream.send(input)
        self.bidirectionalStream.close()
    }
}
