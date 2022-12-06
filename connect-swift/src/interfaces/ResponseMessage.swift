import Wire

public struct ResponseMessage<Output: Wire.ProtoCodable> {
    public let code: Code
    public let headers: Headers
    public let message: Output?
    public let error: ConnectError?
}
