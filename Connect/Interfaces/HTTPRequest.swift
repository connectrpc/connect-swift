import Foundation

public struct HTTPRequest {
    public let target: URL
    public let contentType: String
    public let headers: Headers
    public let message: Data?

    public init(target: URL, contentType: String, headers: Headers, message: Data?) {
        self.target = target
        self.contentType = contentType
        self.headers = headers
        self.message = message
    }
}
