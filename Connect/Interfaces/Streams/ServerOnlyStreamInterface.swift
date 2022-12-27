import SwiftProtobuf

/// Represents a server-only stream (a stream where the server streams data to the client after
/// receiving an initial request) that can send request messages.
public protocol ServerOnlyStreamInterface<Input> {
    /// The input (request) message type.
    associatedtype Input: SwiftProtobuf.Message

    /// Send a request to the server over the stream.
    ///
    /// Should be called exactly one time when starting the stream.
    ///
    /// - parameter input: The request message to send.
    func send(_ input: Input) throws
}
