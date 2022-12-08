import Foundation
import SwiftProtobuf

public struct ProtoCodec {
    public init() {}
}

extension ProtoCodec: Codec {
    public func name() -> String {
        return "proto"
    }

    public func serialize<Input: SwiftProtobuf.Message>(message: Input) throws -> Data {
        return try message.serializedData()
    }

    public func deserialize<Output: SwiftProtobuf.Message>(source: Data) throws -> Output {
        return try Output(serializedData: source)
    }
}
