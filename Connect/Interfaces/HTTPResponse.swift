import Foundation

/// Unary HTTP response received from the server.
public struct HTTPResponse {
    /// The status code of the response.
    public let code: Code
    /// Response headers specified by the server.
    public let headers: Headers
    /// Body data provided by the server.
    public let message: Data?
    /// Trailers provided by the server.
    public let trailers: Trailers
    /// The accompanying error, if the request failed.
    public let error: Swift.Error?
}
