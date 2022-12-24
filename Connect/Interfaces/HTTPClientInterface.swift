public protocol HTTPClientInterface {
    @discardableResult
    func unary(request: HTTPRequest, completion: @escaping (HTTPResponse) -> Void) -> Cancelable

    func stream(request: HTTPRequest, responseCallbacks: ResponseCallbacks) -> RequestCallbacks
}
