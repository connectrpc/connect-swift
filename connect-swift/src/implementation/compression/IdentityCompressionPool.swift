import Foundation

/// Compression pool that keeps data in its default untransformed ("identity") state.
public struct IdentityCompressionPool {
    public init() {}
}

extension IdentityCompressionPool: CompressionPool {
    public static func name() -> String {
        return "identity"
    }

    public func compress(data: Data) throws -> Data {
        return data
    }

    public func decompress(data: Data) throws -> Data {
        return data
    }
}
