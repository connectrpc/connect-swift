import Foundation
import Wire

public struct ProtoCodec {
    public init() {}
}

extension ProtoCodec: Codec {
    public func name() -> String {
        return "proto"
    }

    public func serialize<Input: ProtoEncodable & Encodable>(message: Input) throws -> Data {
        return try ProtoEncoder().encode(message)
    }

    public func deserialize<Output: ProtoDecodable & Decodable>(source: Data) throws -> Output {
        return try ProtoDecoder(enumDecodingStrategy: .returnNil)
            .decode(Output.self, from: source)
    }
}
