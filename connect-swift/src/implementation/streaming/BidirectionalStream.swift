import os.log
import Wire

/// Concrete implementation of `BidirectionalStreamInterface`.
final class BidirectionalStream<Message: Wire.ProtoEncodable & Swift.Encodable> {
    private let requestCallbacks: RequestCallbacks
    private let codec: Codec

    init(requestCallbacks: RequestCallbacks, codec: Codec) {
        self.requestCallbacks = requestCallbacks
        self.codec = codec
    }
}

extension BidirectionalStream: BidirectionalStreamInterface {
    typealias Input = Message

    @discardableResult
    func send(_ input: Input) throws -> Self {
        self.requestCallbacks.sendData(try self.codec.serialize(message: input))
        return self
    }

    func close() {
        self.requestCallbacks.sendClose()
    }
}
