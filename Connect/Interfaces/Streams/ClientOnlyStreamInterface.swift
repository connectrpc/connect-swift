import SwiftProtobuf

public protocol ClientOnlyStreamInterface<Input> {
    associatedtype Input: SwiftProtobuf.Message

    @discardableResult
    func send(_ input: Input) throws -> Self

    func close()
}
