import Foundation
import SwiftProtobuf

public struct JSONCodec {
    private let decodingOptions: JSONDecodingOptions = {
        var options = JSONDecodingOptions()
        options.ignoreUnknownFields = true
        return options
    }()

    public init() {}
}

extension JSONCodec: Codec {
    public func name() -> String {
        return "json"
    }

    public func serialize<Input: SwiftProtobuf.Message>(message: Input) throws -> Data {
        // TODO: Expose support for `JSONEncodingOptions`?
        return try message.jsonUTF8Data()
    }

    public func deserialize<Output: SwiftProtobuf.Message>(source: Data) throws -> Output {
        return try Output(jsonUTF8Data: source, options: self.decodingOptions)
    }
}
