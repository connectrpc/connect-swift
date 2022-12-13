import Foundation
import SwiftProtobuf

public protocol ProtocolClientInterface {
    func unary<
        Input: SwiftProtobuf.Message, Output: SwiftProtobuf.Message
    >(
        path: String,
        request: Input,
        headers: Headers,
        completion: @escaping (ResponseMessage<Output>) -> Void
    )

    func bidirectionalStream<
        Input: SwiftProtobuf.Message, Output: SwiftProtobuf.Message
    >(
        path: String,
        headers: Headers,
        onResult: @escaping (StreamResult<Output>) -> Void
    ) -> any BidirectionalStreamInterface<Input>

    func clientOnlyStream<
        Input: SwiftProtobuf.Message, Output: SwiftProtobuf.Message
    >(
        path: String,
        headers: Headers,
        onResult: @escaping (StreamResult<Output>) -> Void
    ) -> any ClientOnlyStreamInterface<Input>

    func serverOnlyStream<
        Input: SwiftProtobuf.Message, Output: SwiftProtobuf.Message
    >(
        path: String,
        headers: Headers,
        onResult: @escaping (StreamResult<Output>) -> Void
    ) -> any ServerOnlyStreamInterface<Input>
}
