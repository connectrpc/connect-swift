import Foundation

/// Interceptors can be registered with clients as a way to observe and/or alter outbound requests
/// and inbound responses.
///
/// Interceptors are expected to be instantiated once per request/stream.
public protocol Interceptor {
    /// Invoked when a unary call is started. Provides a set of closures that will be called
    /// as the request progresses, allowing the interceptor to alter request/response data.
    ///
    /// - parameter nextUnary: The set of closures which will be invoked after this interceptor.
    ///                        Represents either another interceptor or client's invocation.
    ///
    /// - returns: A new set of closures which can be used to read/alter request/response data.
    func wrapUnary(nextUnary: UnaryFunction) -> UnaryFunction

    /// Invoked when a streaming call is started. Provides a set of closures that will be called
    /// as the stream progresses, allowing the interceptor to alter request/response data.
    ///
    /// NOTE: Closures may be called multiple times as the stream progresses (for example, as data
    /// is sent/received over the stream). Furthermore, a guarantee is provided that each data chunk
    /// will contain 1 full message (for Connect and gRPC, this includes the prefix and message
    /// length bytes, followed by the actual message data).
    ///
    /// - parameter nextStream: The set of closures which will be invoked after this interceptor.
    ///                         Represents either another interceptor or the client's invocation.
    ///
    /// - returns: A new set of closures which can be used to read/alter request/response data.
    func wrapStream(nextStream: StreamingFunction) -> StreamingFunction
}

public struct UnaryFunction {
    public let requestFunction: (HTTPRequest) -> HTTPRequest
    public let responseFunction: (HTTPResponse) -> HTTPResponse

    public static func identity() -> Self {
        return .init(requestFunction: { $0 }, responseFunction: { $0 })
    }
}

public struct StreamingFunction {
    public let requestFunction: (HTTPRequest) -> HTTPRequest
    public let requestDataFunction: (Data) -> Data
    public let streamResultFunc: (StreamResult<Data>) -> StreamResult<Data>

    public static func identity() -> Self {
        return .init(
            requestFunction: { $0 },
            requestDataFunction: { $0 },
            streamResultFunc: { $0 }
        )
    }
}
