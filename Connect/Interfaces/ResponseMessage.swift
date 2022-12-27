import SwiftProtobuf

/// Typed unary response from an RPC.
public struct ResponseMessage<Output: SwiftProtobuf.Message> {
    /// The status code of the response.
    public let code: Code
    /// Response headers specified by the server.
    public let headers: Headers
    /// Typed response message provided by the server.
    public let message: Output?
    /// Trailers provided by the server.
    public let trailers: Trailers
    /// The accompanying error, if the request failed.
    public let error: ConnectError?

    public init(
        code: Code, headers: Headers, message: Output?,
        trailers: Trailers, error: ConnectError?
    ) {
        self.code = code
        self.headers = headers
        self.message = message
        self.trailers = trailers
        self.error = error
    }
}
