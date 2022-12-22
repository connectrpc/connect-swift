import SwiftProtobuf

public protocol ServerOnlyAsyncStreamInterface<Input, Output> {
    associatedtype Input: SwiftProtobuf.Message
    associatedtype Output: SwiftProtobuf.Message

    func send(_ input: Input) throws

    func results() -> AsyncStream<Output>
}
