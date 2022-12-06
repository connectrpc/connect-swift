@frozen
public enum StreamResult<Output> {
    case complete(error: Swift.Error?, trailers: Trailers?)
    case headers(Headers)
    case message(Output)
}
