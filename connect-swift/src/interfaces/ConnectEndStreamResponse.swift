/// Structure modeling the final JSON message that is returned by Connect streams:
/// https://connect.build/docs/protocol#error-end-stream
public struct ConnectEndStreamResponse {
    /// Connect error that was returned with the response.
    public let error: ConnectError?
    /// Additional metadata that was passed with the response. Keys are guaranteed to be lowercased.
    public let metadata: Trailers?
}

extension ConnectEndStreamResponse: Decodable {
    private enum CodingKeys: String, CodingKey {
        case error = "error"
        case metadata = "metadata"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawMetadata = try container.decodeIfPresent(Trailers.self, forKey: .metadata)
        self.init(
            error: try container.decodeIfPresent(ConnectError.self, forKey: .error),
            metadata: rawMetadata?.reduce(into: Trailers()) { trailers, current in
                trailers[current.key.lowercased()] = current.value
            }
        )
    }
}
