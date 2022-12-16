import Foundation

/// Interceptors can be registered with clients as a way to observe and/or alter outbound requests
/// and inbound responses.
///
/// Interceptors are expected to be instantiated once per request/stream.
public protocol Interceptor {
    /// Invoked when a unary call is started. Provides a set of closures that will be called
    /// as the request progresses, allowing the interceptor to alter request/response data.
    ///
    /// - returns: A new set of closures which can be used to read/alter request/response data.
    func unaryFunction() -> UnaryFunction

    /// Invoked when a streaming call is started. Provides a set of closures that will be called
    /// as the stream progresses, allowing the interceptor to alter request/response data.
    ///
    /// NOTE: Closures may be called multiple times as the stream progresses (for example, as data
    /// is sent/received over the stream). Furthermore, a guarantee is provided that each data chunk
    /// will contain 1 full message (for Connect and gRPC, this includes the prefix and message
    /// length bytes, followed by the actual message data).
    ///
    /// - returns: A new set of closures which can be used to read/alter request/response data.
    func streamFunction() -> StreamFunction
}

public struct UnaryFunction {
    public let requestFunction: (HTTPRequest) -> HTTPRequest
    public let responseFunction: (HTTPResponse) -> HTTPResponse

    public init(
        requestFunction: @escaping (HTTPRequest) -> HTTPRequest,
        responseFunction: @escaping (HTTPResponse) -> HTTPResponse
    ) {
        self.requestFunction = requestFunction
        self.responseFunction = responseFunction
    }
}

public struct StreamFunction {
    public let requestFunction: (HTTPRequest) -> HTTPRequest
    public let requestDataFunction: (Data) -> Data
    public let streamResultFunc: (StreamResult<Data>) -> StreamResult<Data>

    public init(
        requestFunction: @escaping (HTTPRequest) -> HTTPRequest,
        requestDataFunction: @escaping (Data) -> Data,
        streamResultFunc: @escaping (StreamResult<Data>) -> StreamResult<Data>
    ) {
        self.requestFunction = requestFunction
        self.requestDataFunction = requestDataFunction
        self.streamResultFunc = streamResultFunc
    }
}
