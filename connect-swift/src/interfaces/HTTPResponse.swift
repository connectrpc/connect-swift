import Foundation

public struct HTTPResponse {
    public let code: Code
    public let headers: Headers
    public let message: Data?
    public let trailers: Trailers?
    public let error: Swift.Error?
}
