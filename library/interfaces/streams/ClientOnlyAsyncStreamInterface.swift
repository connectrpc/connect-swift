import SwiftProtobuf

public protocol ClientOnlyAsyncStreamInterface<Input, Output> {
    associatedtype Input: SwiftProtobuf.Message
    associatedtype Output: SwiftProtobuf.Message

    @discardableResult
    func send(_ input: Input) throws -> Self

    func results() -> AsyncStream<StreamResult<Output>>

    func close()
}
