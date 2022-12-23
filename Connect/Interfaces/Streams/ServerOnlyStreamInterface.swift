import SwiftProtobuf

public protocol ServerOnlyStreamInterface<Input> {
    associatedtype Input: SwiftProtobuf.Message

    func send(_ input: Input) throws
}
