import Wire

public protocol ServerOnlyStreamInterface<Input> {
    associatedtype Input: Wire.ProtoEncodable & Swift.Encodable

    func send(_ input: Input) throws
}
