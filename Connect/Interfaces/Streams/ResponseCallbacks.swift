import Foundation

/// Set of closures that are used for wiring inbound response data through from HTTP clients.
public final class ResponseCallbacks {
    /// Closure to call when response headers are available.
    public let receiveResponseHeaders: (Headers) -> Void
    /// Closure to call when response data is available.
    public let receiveResponseData: (Data) -> Void
    /// Closure to call when a stream is closed. Includes the status code and potentially an error.
    public let receiveClose: (Code, Swift.Error?) -> Void

    public init(
        receiveResponseHeaders: @escaping (Headers) -> Void,
        receiveResponseData: @escaping (Data) -> Void,
        receiveClose: @escaping (Code, Swift.Error?) -> Void
    ) {
        self.receiveResponseHeaders = receiveResponseHeaders
        self.receiveResponseData = receiveResponseData
        self.receiveClose = receiveClose
    }
}
