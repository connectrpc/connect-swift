import SwiftProtobuf

/// Represents a server-only stream (a stream where the server streams data to the client after
/// receiving an initial request) that can be interacted with using async/await.
public protocol ServerOnlyAsyncStreamInterface<Input, Output> {
    /// The input (request) message type.
    associatedtype Input: SwiftProtobuf.Message

    /// The output (response) message type.
    associatedtype Output: SwiftProtobuf.Message

    /// Send a request to the server over the stream.
    ///
    /// Should be called exactly one time when starting the stream.
    ///
    /// - parameter input: The request message to send.
    func send(_ input: Input) throws

    /// Obtain an await-able list of results from the stream using async/await.
    ///
    /// Example usage: `for await result in stream.results() {...}`
    ///
    /// - returns: An `AsyncStream` that contains all outputs/results from the stream.
    func results() -> AsyncStream<StreamResult<Output>>
}
