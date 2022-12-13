public protocol HTTPClientInterface {
    // TODO: Allow for canceling (return a `Cancellable`?)
    func unary(request: HTTPRequest, completion: @escaping (HTTPResponse) -> Void)

    func stream(request: HTTPRequest, responseCallbacks: ResponseCallbacks) -> RequestCallbacks
}
