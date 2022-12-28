import Foundation

/// HTTP request used for sending primitive data to the server.
public struct HTTPRequest {
    /// Target URL for the request.
    public let target: URL
    /// Value to assign to the `content-type` header.
    public let contentType: String
    /// Additional outbound headers for the request.
    public let headers: Headers
    /// Body data to send with the request.
    public let message: Data?

    public init(target: URL, contentType: String, headers: Headers, message: Data?) {
        self.target = target
        self.contentType = contentType
        self.headers = headers
        self.message = message
    }
}
