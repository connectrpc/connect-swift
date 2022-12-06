import Foundation

public final class ResponseCallbacks {
    public let receiveResponseHeaders: (Headers) -> Void
    public let receiveResponseData: (Data) -> Void
    public let receiveClose: (Swift.Error?) -> Void

    public init(
        receiveResponseHeaders: @escaping (Headers) -> Void,
        receiveResponseData: @escaping (Data) -> Void,
        receiveClose: @escaping (Swift.Error?) -> Void
    ) {
        self.receiveResponseHeaders = receiveResponseHeaders
        self.receiveResponseData = receiveResponseData
        self.receiveClose = receiveClose
    }
}
