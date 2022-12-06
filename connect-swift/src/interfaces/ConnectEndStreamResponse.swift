/// Structure modeling the final JSON message that is returned by Connect streams:
/// https://connect.build/docs/protocol#error-end-stream
public struct ConnectEndStreamResponse {
    public let error: ConnectError?
    public let metadata: [String: [String]]?
}

extension ConnectEndStreamResponse: Decodable {
    private enum CodingKeys: String, CodingKey {
        case error = "error"
        case metadata = "metadata"
    }
}
