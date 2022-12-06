import Foundation
import Wire

public struct JSONCodec {
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init() {}
}

extension JSONCodec: Codec {
    public func name() -> String {
        return "json"
    }

    public func serialize<Input: ProtoEncodable & Encodable>(message: Input) throws -> Data {
        return try self.encoder.encode(message)
    }

    public func deserialize<Output: ProtoDecodable & Decodable>(source: Data) throws -> Output {
        return try self.decoder.decode(Output.self, from: source)
    }
}
