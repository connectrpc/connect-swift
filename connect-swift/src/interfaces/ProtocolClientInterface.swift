import Foundation
import Wire

public protocol ProtocolClientInterface {
    func unary<
        Input: Wire.ProtoEncodable & Swift.Encodable, Output: Wire.ProtoDecodable & Swift.Decodable
    >(
        path: String,
        request: Input,
        headers: Headers,
        completion: @escaping (ResponseMessage<Output>) -> Void
    )

    func bidirectionalStream<
        Input: Wire.ProtoEncodable & Swift.Encodable, Output: Wire.ProtoDecodable & Swift.Decodable
    >(
        path: String,
        headers: Headers,
        onResult: @escaping (StreamResult<Output>) -> Void
    ) -> any BidirectionalStreamInterface<Input>

    func clientOnlyStream<
        Input: Wire.ProtoEncodable & Swift.Encodable, Output: Wire.ProtoDecodable & Swift.Decodable
    >(
        path: String,
        headers: Headers,
        onResult: @escaping (StreamResult<Output>) -> Void
    ) -> any ClientOnlyStreamInterface<Input>

    func serverOnlyStream<
        Input: Wire.ProtoEncodable & Swift.Encodable, Output: Wire.ProtoDecodable & Swift.Decodable
    >(
        path: String,
        headers: Headers,
        onResult: @escaping (StreamResult<Output>) -> Void
    ) -> any ServerOnlyStreamInterface<Input>
}
