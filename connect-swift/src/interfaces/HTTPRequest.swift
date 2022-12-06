import Foundation

public struct HTTPRequest {
    public let target: URL
    public let contentType: String
    public let headers: Headers
    public let message: Data?
}
