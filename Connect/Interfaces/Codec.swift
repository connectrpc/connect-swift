import Foundation
import SwiftProtobuf

/// Defines a type that is capable of encoding and decoding messages using a specific format.
public protocol Codec {
    /// - returns: The name of the codec's format (e.g., "json", "protobuf"). Usually consumed
    ///            in the form of adding the `content-type` header via "application/{name}".
    func name() -> String

    /// Serializes the input message into the codec's format.
    ///
    /// - parameter message: Typed input message.
    ///
    /// - returns: Serialized data that can be transmitted.
    func serialize<Input: SwiftProtobuf.Message>(message: Input) throws -> Data

    /// Deserializes data in the codec's format into a typed message.
    ///
    /// - parameter source: The source data to deserialize.
    ///
    /// - returns: The typed output message.
    func deserialize<Output: SwiftProtobuf.Message>(source: Data) throws -> Output
}
