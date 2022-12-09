import SwiftProtobuf

public struct ResponseMessage<Output: SwiftProtobuf.Message> {
    public let code: Code
    public let headers: Headers
    public let message: Output?
    public let trailers: Trailers
    public let error: ConnectError?
}
