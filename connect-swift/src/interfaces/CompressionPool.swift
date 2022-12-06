import Foundation

public protocol CompressionPool {
    static func name() -> String

    func compress(data: Data) throws -> Data

    func decompress(data: Data) throws -> Data
}
