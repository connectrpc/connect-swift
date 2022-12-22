import SwiftProtobuf

public protocol BidirectionalAsyncStreamInterface<Input, Output> {
    associatedtype Input: SwiftProtobuf.Message
    associatedtype Output: SwiftProtobuf.Message

    @discardableResult
    func send(_ input: Input) throws -> Self

    func results() -> AsyncStream<Output>

    func close()
}
