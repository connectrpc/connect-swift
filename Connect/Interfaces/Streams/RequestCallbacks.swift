import Foundation

/// Set of closures that are used for wiring outbound request data through to HTTP clients.
public final class RequestCallbacks {
    /// Closure to send data through to the server.
    public let sendData: (Data) -> Void
    /// Closure to initiate a close for a stream.
    public let sendClose: () -> Void

    public init(sendData: @escaping (Data) -> Void, sendClose: @escaping () -> Void) {
        self.sendData = sendData
        self.sendClose = sendClose
    }
}
