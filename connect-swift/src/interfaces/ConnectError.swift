import Foundation

public struct ConnectError: Swift.Error {
    public let code: Code
    public let message: String?
    public let exception: Swift.Error?
    public let details: [Detail]
    public private(set) var metadata: Headers

    /// Error details are sent over the network to clients, which can then work with
    /// strongly-typed data rather than trying to parse a complex error message. For
    /// example, you might use details to send a localized error message or retry
    /// parameters to the client.
    ///
    /// The `google.golang.org/genproto/googleapis/rpc/errdetails` package contains a
    /// variety of Protobuf messages commonly used as error details.
    public struct Detail: Decodable {
        public let type: String
        public let payload: String?

        private enum CodingKeys: String, CodingKey {
            case type = "type"
            case payload = "value"
        }
    }
}

extension ConnectError: Decodable {
    private enum CodingKeys: String, CodingKey {
        case code = "code"
        case message = "message"
        case details = "details"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            code: Code.fromName(try container.decode(String.self, forKey: .code)),
            message: try container.decodeIfPresent(String.self, forKey: .message),
            exception: nil,
            details: try container.decodeIfPresent([Detail].self, forKey: .details) ?? [],
            metadata: [:]
        )
    }
}

extension ConnectError {
    public static func from(code: Code, headers: Headers, source: Data?) -> Self {
        guard let source = source else {
            return ConnectError(
                code: code, message: "empty error message from source", exception: nil,
                details: [], metadata: headers
            )
        }

        do {
            var connectError = try JSONDecoder().decode(ConnectError.self, from: source)
            connectError.metadata = headers
            return connectError
        } catch let error {
            return ConnectError(
                code: code, message: String(data: source, encoding: .utf8),
                exception: error, details: [], metadata: headers
            )
        }
    }
}
