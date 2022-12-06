// Code generated by Wire protocol buffer compiler, do not edit.
// Source: grpc.testing.StreamingOutputCallRequest in grpc/testing/messages.proto
import Foundation
import Wire

/**
 *  Server-streaming request.
 */
public struct StreamingOutputCallRequest {

    /**
     *  Desired payload type in the response from the server.
     *  If response_type is RANDOM, the payload from each response in the stream
     *  might be of different types. This is to simulate a mixed type of payload
     *  stream.
     */
    public var response_type: PayloadType
    /**
     *  Configuration for each expected response message.
     */
    public var response_parameters: [ResponseParameters]
    /**
     *  Optional input payload sent along with the request.
     */
    public var payload: Payload?
    /**
     *  Whether server should return a given status
     */
    public var response_status: EchoStatus?
    public var unknownFields: Data = .init()

    public init(
        response_type: PayloadType,
        response_parameters: [ResponseParameters] = [],
        payload: Payload? = nil,
        response_status: EchoStatus? = nil
    ) {
        self.response_type = response_type
        self.response_parameters = response_parameters
        self.payload = payload
        self.response_status = response_status
    }

}

#if !WIRE_REMOVE_EQUATABLE
extension StreamingOutputCallRequest : Equatable {
}
#endif

#if !WIRE_REMOVE_HASHABLE
extension StreamingOutputCallRequest : Hashable {
}
#endif

extension StreamingOutputCallRequest : ProtoMessage {
    public static func protoMessageTypeURL() -> String {
        return "type.googleapis.com/grpc.testing.StreamingOutputCallRequest"
    }
}

extension StreamingOutputCallRequest : Proto3Codable {
    public init(from reader: ProtoReader) throws {
        var response_type: PayloadType? = nil
        var response_parameters: [ResponseParameters] = []
        var payload: Payload? = nil
        var response_status: EchoStatus? = nil

        let token = try reader.beginMessage()
        while let tag = try reader.nextTag(token: token) {
            switch tag {
            case 1: response_type = try reader.decode(PayloadType.self)
            case 2: try reader.decode(into: &response_parameters)
            case 3: payload = try reader.decode(Payload.self)
            case 7: response_status = try reader.decode(EchoStatus.self)
            default: try reader.readUnknownField(tag: tag)
            }
        }
        self.unknownFields = try reader.endMessage(token: token)

        self.response_type = try StreamingOutputCallRequest.checkIfMissing(response_type, "response_type")
        self.response_parameters = response_parameters
        self.payload = payload
        self.response_status = response_status
    }

    public func encode(to writer: ProtoWriter) throws {
        try writer.encode(tag: 1, value: self.response_type)
        try writer.encode(tag: 2, value: self.response_parameters)
        try writer.encode(tag: 3, value: self.payload)
        try writer.encode(tag: 7, value: self.response_status)
        try writer.writeUnknownFields(unknownFields)
    }
}

#if !WIRE_REMOVE_CODABLE
extension StreamingOutputCallRequest : Codable {
    public enum CodingKeys : String, CodingKey {

        case response_type
        case response_parameters
        case payload
        case response_status

    }
}
#endif
