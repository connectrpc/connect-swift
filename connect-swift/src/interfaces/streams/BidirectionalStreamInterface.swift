import SwiftProtobuf

public protocol BidirectionalStreamInterface<Input> {
    associatedtype Input: SwiftProtobuf.Message

    @discardableResult
    func send(_ input: Input) throws -> Self

    func close()
}
