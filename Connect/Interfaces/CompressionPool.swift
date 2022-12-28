import Foundation

/// Conforming types provide the functionality to compress/decompress data using a specific
/// algorithm.
///
/// `ProtocolClientInterface` implementations are expected to use the first compression pool with
/// a matching `name()` for decompressing inbound responses.
///
/// Outbound request compression can be specified using additional options that specify a
/// `compressionName` that matches a compression pool's `name()`.
public protocol CompressionPool {
    /// The name of the compression pool, which corresponds to the `content-encoding` header.
    /// Example: `gzip`.
    ///
    /// - returns: The name of the compression pool that can be used with the `content-encoding`
    ///            header.
    static func name() -> String

    /// Compress an outbound request message.
    ///
    /// - parameter data: The uncompressed request message.
    ///
    /// - returns: The compressed request message.
    func compress(data: Data) throws -> Data

    /// Decompress an inbound response message.
    ///
    /// - parameter data: The compressed response message.
    ///
    /// - returns: The uncompressed response message.
    func decompress(data: Data) throws -> Data
}
