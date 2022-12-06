import Wire

public protocol ClientOnlyStreamInterface<Input> {
    associatedtype Input: Wire.ProtoEncodable & Swift.Encodable

    @discardableResult
    func send(_ input: Input) throws -> Self

    func close()
}
