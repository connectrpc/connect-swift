/// Enumeration of result states that can be received over streams.
///
/// A typical stream receives `headers > message > message > message ... > complete`.
@frozen
public enum StreamResult<Output> {
    /// Stream is complete. Provides the end status code and optionally an error and trailers.
    case complete(code: Code, error: Swift.Error?, trailers: Trailers?)
    /// Headers have been received over the stream.
    case headers(Headers)
    /// A response message has been received over the stream.
    case message(Output)
}
