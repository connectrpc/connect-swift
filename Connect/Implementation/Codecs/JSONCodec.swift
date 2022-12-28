import Foundation
import SwiftProtobuf

public struct JSONCodec {
    private let encodingOptions: JSONEncodingOptions
    private let decodingOptions: JSONDecodingOptions = {
        var options = JSONDecodingOptions()
        options.ignoreUnknownFields = true
        return options
    }()

    /// Designated initializer.
    ///
    /// - parameter alwaysPrintEnumsAsInts: Always print enums as ints. By default they are printed
    ///                                     as strings.
    /// - parameter preserveProtoFieldNames: Whether to preserve proto field names. By default they
    ///                                      are converted to JSON (lowerCamelCase) names.
    public init(alwaysEncodeEnumsAsInts: Bool = false, encodeProtoFieldNames: Bool = false) {
        var encodingOptions = JSONEncodingOptions()
        encodingOptions.alwaysPrintEnumsAsInts = alwaysEncodeEnumsAsInts
        encodingOptions.preserveProtoFieldNames = encodeProtoFieldNames
        self.encodingOptions = encodingOptions
    }
}

extension JSONCodec: Codec {
    public func name() -> String {
        return "json"
    }

    public func serialize<Input: SwiftProtobuf.Message>(message: Input) throws -> Data {
        return try message.jsonUTF8Data(options: self.encodingOptions)
    }

    public func deserialize<Output: SwiftProtobuf.Message>(source: Data) throws -> Output {
        return try Output(jsonUTF8Data: source, options: self.decodingOptions)
    }
}
