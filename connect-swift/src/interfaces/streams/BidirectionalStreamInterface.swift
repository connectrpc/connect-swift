import Wire

public protocol BidirectionalStreamInterface<Input> {
    associatedtype Input: Wire.ProtoEncodable & Swift.Encodable

    @discardableResult
    func send(_ input: Input) throws -> Self

    func close()
}
