import SwiftProtobuf

/// Represents a bidirectional stream that can be interacted with using async/await.
public protocol BidirectionalAsyncStreamInterface<Input, Output> {
    /// The input (request) message type.
    associatedtype Input: SwiftProtobuf.Message

    /// The output (response) message type.
    associatedtype Output: SwiftProtobuf.Message

    /// Send a request to the server over the stream.
    ///
    /// - parameter input: The request message to send.
    ///
    /// - returns: An instance of this stream, for syntactic sugar.
    @discardableResult
    func send(_ input: Input) throws -> Self

    /// Obtain an await-able list of results from the stream using async/await.
    ///
    /// Example usage: `for await result in stream.results() {...}`
    ///
    /// - returns: An `AsyncStream` that contains all outputs/results from the stream.
    func results() -> AsyncStream<StreamResult<Output>>

    /// Close the stream. No calls to `send()` are valid after calling `close()`.
    func close()
}
