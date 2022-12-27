/// Interface for a client that performs underlying HTTP requests and streams with primitive types.
public protocol HTTPClientInterface {
    /// Perform a unary HTTP request.
    ///
    /// - parameter request: The outbound request headers and data.
    /// - parameter completion: Closure that should be called upon completion of the request.
    ///
    /// - returns: A type which can be used to cancel the outbound request.
    @discardableResult
    func unary(request: HTTPRequest, completion: @escaping (HTTPResponse) -> Void) -> Cancelable

    /// Initialize a new HTTP stream.
    ///
    /// - parameter request: The request headers to use for starting the stream.
    /// - parameter responseCallbacks: Set of callbacks that should be invoked by the HTTP client
    ///                                when response data is received from the server.
    ///
    /// - returns: Set of callbacks which can be called to send data over the stream or to close it.
    func stream(request: HTTPRequest, responseCallbacks: ResponseCallbacks) -> RequestCallbacks
}
