@frozen
public enum StreamResult<Output> {
    case complete(code: Code, error: Swift.Error?, trailers: Trailers?)
    case headers(Headers)
    case message(Output)
}
