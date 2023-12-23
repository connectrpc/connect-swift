// Code generated by protoc-gen-connect-swift. DO NOT EDIT.
//
// Source: connectrpc/conformance/v1/service.proto
//

import Connect
import Foundation
import SwiftProtobuf

/// The service implemented by conformance test servers. This is implemented by
/// the reference servers, used to test clients, and is expected to be implemented
/// by test servers, since this is the service used by reference clients.
///
/// Test servers must implement the service as described.
internal protocol Connectrpc_Conformance_V1_ConformanceServiceClientInterface: Sendable {

    /// If the response_delay_ms duration is specified, the server should wait the
    /// given duration after reading the request before sending the corresponding
    /// response.
    ///
    /// Servers should allow the response definition to be unset in the request and
    /// if it is, set no response headers or trailers and return no response data.
    /// The returned payload should only contain the request info.
    @discardableResult
    func `unary`(request: Connectrpc_Conformance_V1_UnaryRequest, headers: Connect.Headers, completion: @escaping @Sendable (ResponseMessage<Connectrpc_Conformance_V1_UnaryResponse>) -> Void) -> Connect.Cancelable

    /// If the response_delay_ms duration is specified, the server should wait the
    /// given duration after reading the request before sending the corresponding
    /// response.
    ///
    /// Servers should allow the response definition to be unset in the request and
    /// if it is, set no response headers or trailers and return no response data.
    /// The returned payload should only contain the request info.
    @available(iOS 13, *)
    func `unary`(request: Connectrpc_Conformance_V1_UnaryRequest, headers: Connect.Headers) async -> ResponseMessage<Connectrpc_Conformance_V1_UnaryResponse>

    /// A server-streaming operation. The request indicates the response headers,
    /// response messages, trailers, and an optional error to send back. The
    /// response data should be sent in the order indicated, and the server should
    /// wait between sending response messages as indicated.
    ///
    /// Response message data is specified as bytes. The service should echo back
    /// request properties in the first ConformancePayload, and then include the
    /// message data in the data field. Subsequent messages after the first one
    /// should contain only the data field.
    ///
    /// Servers should immediately send response headers on the stream before sleeping
    /// for any specified response delay and/or sending the first message so that
    /// clients can be unblocked reading response headers.
    ///
    /// If a response definition is not specified OR is specified, but response data
    /// is empty, the server should skip sending anything on the stream. When there
    /// are no responses to send, servers should throw an error if one is provided
    /// and return without error if one is not. Stream headers and trailers should
    /// still be set on the stream if provided regardless of whether a response is
    /// sent or an error is thrown.
    func `serverStream`(headers: Connect.Headers, onResult: @escaping @Sendable (Connect.StreamResult<Connectrpc_Conformance_V1_ServerStreamResponse>) -> Void) -> any Connect.ServerOnlyStreamInterface<Connectrpc_Conformance_V1_ServerStreamRequest>

    /// A server-streaming operation. The request indicates the response headers,
    /// response messages, trailers, and an optional error to send back. The
    /// response data should be sent in the order indicated, and the server should
    /// wait between sending response messages as indicated.
    ///
    /// Response message data is specified as bytes. The service should echo back
    /// request properties in the first ConformancePayload, and then include the
    /// message data in the data field. Subsequent messages after the first one
    /// should contain only the data field.
    ///
    /// Servers should immediately send response headers on the stream before sleeping
    /// for any specified response delay and/or sending the first message so that
    /// clients can be unblocked reading response headers.
    ///
    /// If a response definition is not specified OR is specified, but response data
    /// is empty, the server should skip sending anything on the stream. When there
    /// are no responses to send, servers should throw an error if one is provided
    /// and return without error if one is not. Stream headers and trailers should
    /// still be set on the stream if provided regardless of whether a response is
    /// sent or an error is thrown.
    @available(iOS 13, *)
    func `serverStream`(headers: Connect.Headers) -> any Connect.ServerOnlyAsyncStreamInterface<Connectrpc_Conformance_V1_ServerStreamRequest, Connectrpc_Conformance_V1_ServerStreamResponse>

    /// A client-streaming operation. The first request indicates the response
    /// headers and trailers and also indicates either a response message or an
    /// error to send back.
    ///
    /// Response message data is specified as bytes. The service should echo back
    /// request properties, including all request messages in the order they were
    /// received, in the ConformancePayload and then include the message data in
    /// the data field.
    ///
    /// If the input stream is empty, the server's response will include no data,
    /// only the request properties (headers, timeout).
    ///
    /// Servers should only read the response definition from the first message in
    /// the stream and should ignore any definition set in subsequent messages.
    ///
    /// Servers should allow the response definition to be unset in the request and
    /// if it is, set no response headers or trailers and return no response data.
    /// The returned payload should only contain the request info.
    func `clientStream`(headers: Connect.Headers, onResult: @escaping @Sendable (Connect.StreamResult<Connectrpc_Conformance_V1_ClientStreamResponse>) -> Void) -> any Connect.ClientOnlyStreamInterface<Connectrpc_Conformance_V1_ClientStreamRequest>

    /// A client-streaming operation. The first request indicates the response
    /// headers and trailers and also indicates either a response message or an
    /// error to send back.
    ///
    /// Response message data is specified as bytes. The service should echo back
    /// request properties, including all request messages in the order they were
    /// received, in the ConformancePayload and then include the message data in
    /// the data field.
    ///
    /// If the input stream is empty, the server's response will include no data,
    /// only the request properties (headers, timeout).
    ///
    /// Servers should only read the response definition from the first message in
    /// the stream and should ignore any definition set in subsequent messages.
    ///
    /// Servers should allow the response definition to be unset in the request and
    /// if it is, set no response headers or trailers and return no response data.
    /// The returned payload should only contain the request info.
    @available(iOS 13, *)
    func `clientStream`(headers: Connect.Headers) -> any Connect.ClientOnlyAsyncStreamInterface<Connectrpc_Conformance_V1_ClientStreamRequest, Connectrpc_Conformance_V1_ClientStreamResponse>

    /// A bidirectional-streaming operation. The first request indicates the response
    /// headers, response messages, trailers, and an optional error to send back.
    /// The response data should be sent in the order indicated, and the server
    /// should wait between sending response messages as indicated.
    ///
    /// Response message data is specified as bytes and should be included in the
    /// data field of the ConformancePayload in each response.
    ///
    /// Servers should send responses indicated according to the rules of half duplex
    /// vs. full duplex streams. Once all responses are sent, the server should either
    /// return an error if specified or close the stream without error.
    ///
    /// Servers should immediately send response headers on the stream before sleeping
    /// for any specified response delay and/or sending the first message so that
    /// clients can be unblocked reading response headers.
    ///
    /// If a response definition is not specified OR is specified, but response data
    /// is empty, the server should skip sending anything on the stream. Stream
    /// headers and trailers should always be set on the stream if provided
    /// regardless of whether a response is sent or an error is thrown.
    ///
    /// If the full_duplex field is true:
    /// - the handler should read one request and then send back one response, and
    ///   then alternate, reading another request and then sending back another response, etc.
    ///
    /// - if the server receives a request and has no responses to send, it
    ///   should throw the error specified in the request.
    ///
    /// - the service should echo back all request properties in the first response
    ///   including the last received request. Subsequent responses should only
    ///   echo back the last received request.
    ///
    /// - if the response_delay_ms duration is specified, the server should wait the given
    ///   duration after reading the request before sending the corresponding
    ///   response.
    ///
    /// If the full_duplex field is false:
    /// - the handler should read all requests until the client is done sending.
    ///   Once all requests are read, the server should then send back any responses
    ///   specified in the response definition.
    ///
    /// - the server should echo back all request properties, including all request
    ///   messages in the order they were received, in the first response. Subsequent
    ///   responses should only include the message data in the data field.
    ///
    /// - if the response_delay_ms duration is specified, the server should wait that
    ///   long in between sending each response message.
    func `bidiStream`(headers: Connect.Headers, onResult: @escaping @Sendable (Connect.StreamResult<Connectrpc_Conformance_V1_BidiStreamResponse>) -> Void) -> any Connect.BidirectionalStreamInterface<Connectrpc_Conformance_V1_BidiStreamRequest>

    /// A bidirectional-streaming operation. The first request indicates the response
    /// headers, response messages, trailers, and an optional error to send back.
    /// The response data should be sent in the order indicated, and the server
    /// should wait between sending response messages as indicated.
    ///
    /// Response message data is specified as bytes and should be included in the
    /// data field of the ConformancePayload in each response.
    ///
    /// Servers should send responses indicated according to the rules of half duplex
    /// vs. full duplex streams. Once all responses are sent, the server should either
    /// return an error if specified or close the stream without error.
    ///
    /// Servers should immediately send response headers on the stream before sleeping
    /// for any specified response delay and/or sending the first message so that
    /// clients can be unblocked reading response headers.
    ///
    /// If a response definition is not specified OR is specified, but response data
    /// is empty, the server should skip sending anything on the stream. Stream
    /// headers and trailers should always be set on the stream if provided
    /// regardless of whether a response is sent or an error is thrown.
    ///
    /// If the full_duplex field is true:
    /// - the handler should read one request and then send back one response, and
    ///   then alternate, reading another request and then sending back another response, etc.
    ///
    /// - if the server receives a request and has no responses to send, it
    ///   should throw the error specified in the request.
    ///
    /// - the service should echo back all request properties in the first response
    ///   including the last received request. Subsequent responses should only
    ///   echo back the last received request.
    ///
    /// - if the response_delay_ms duration is specified, the server should wait the given
    ///   duration after reading the request before sending the corresponding
    ///   response.
    ///
    /// If the full_duplex field is false:
    /// - the handler should read all requests until the client is done sending.
    ///   Once all requests are read, the server should then send back any responses
    ///   specified in the response definition.
    ///
    /// - the server should echo back all request properties, including all request
    ///   messages in the order they were received, in the first response. Subsequent
    ///   responses should only include the message data in the data field.
    ///
    /// - if the response_delay_ms duration is specified, the server should wait that
    ///   long in between sending each response message.
    @available(iOS 13, *)
    func `bidiStream`(headers: Connect.Headers) -> any Connect.BidirectionalAsyncStreamInterface<Connectrpc_Conformance_V1_BidiStreamRequest, Connectrpc_Conformance_V1_BidiStreamResponse>

    /// A unary endpoint that the server should not implement and should instead
    /// return an unimplemented error when invoked.
    @discardableResult
    func `unimplemented`(request: Connectrpc_Conformance_V1_UnimplementedRequest, headers: Connect.Headers, completion: @escaping @Sendable (ResponseMessage<Connectrpc_Conformance_V1_UnimplementedResponse>) -> Void) -> Connect.Cancelable

    /// A unary endpoint that the server should not implement and should instead
    /// return an unimplemented error when invoked.
    @available(iOS 13, *)
    func `unimplemented`(request: Connectrpc_Conformance_V1_UnimplementedRequest, headers: Connect.Headers) async -> ResponseMessage<Connectrpc_Conformance_V1_UnimplementedResponse>

    /// A unary endpoint denoted as having no side effects (i.e. idempotent).
    /// Implementations should use an HTTP GET when invoking this endpoint and
    /// leverage query parameters to send data.
    @discardableResult
    func `idempotentUnary`(request: Connectrpc_Conformance_V1_IdempotentUnaryRequest, headers: Connect.Headers, completion: @escaping @Sendable (ResponseMessage<Connectrpc_Conformance_V1_IdempotentUnaryResponse>) -> Void) -> Connect.Cancelable

    /// A unary endpoint denoted as having no side effects (i.e. idempotent).
    /// Implementations should use an HTTP GET when invoking this endpoint and
    /// leverage query parameters to send data.
    @available(iOS 13, *)
    func `idempotentUnary`(request: Connectrpc_Conformance_V1_IdempotentUnaryRequest, headers: Connect.Headers) async -> ResponseMessage<Connectrpc_Conformance_V1_IdempotentUnaryResponse>
}

/// Concrete implementation of `Connectrpc_Conformance_V1_ConformanceServiceClientInterface`.
internal final class Connectrpc_Conformance_V1_ConformanceServiceClient: Connectrpc_Conformance_V1_ConformanceServiceClientInterface, Sendable {
    private let client: Connect.ProtocolClientInterface

    internal init(client: Connect.ProtocolClientInterface) {
        self.client = client
    }

    @discardableResult
    internal func `unary`(request: Connectrpc_Conformance_V1_UnaryRequest, headers: Connect.Headers = [:], completion: @escaping @Sendable (ResponseMessage<Connectrpc_Conformance_V1_UnaryResponse>) -> Void) -> Connect.Cancelable {
        return self.client.unary(path: "/connectrpc.conformance.v1.ConformanceService/Unary", idempotencyLevel: .unknown, request: request, headers: headers, completion: completion)
    }

    @available(iOS 13, *)
    internal func `unary`(request: Connectrpc_Conformance_V1_UnaryRequest, headers: Connect.Headers = [:]) async -> ResponseMessage<Connectrpc_Conformance_V1_UnaryResponse> {
        return await self.client.unary(path: "/connectrpc.conformance.v1.ConformanceService/Unary", idempotencyLevel: .unknown, request: request, headers: headers)
    }

    internal func `serverStream`(headers: Connect.Headers = [:], onResult: @escaping @Sendable (Connect.StreamResult<Connectrpc_Conformance_V1_ServerStreamResponse>) -> Void) -> any Connect.ServerOnlyStreamInterface<Connectrpc_Conformance_V1_ServerStreamRequest> {
        return self.client.serverOnlyStream(path: "/connectrpc.conformance.v1.ConformanceService/ServerStream", headers: headers, onResult: onResult)
    }

    @available(iOS 13, *)
    internal func `serverStream`(headers: Connect.Headers = [:]) -> any Connect.ServerOnlyAsyncStreamInterface<Connectrpc_Conformance_V1_ServerStreamRequest, Connectrpc_Conformance_V1_ServerStreamResponse> {
        return self.client.serverOnlyStream(path: "/connectrpc.conformance.v1.ConformanceService/ServerStream", headers: headers)
    }

    internal func `clientStream`(headers: Connect.Headers = [:], onResult: @escaping @Sendable (Connect.StreamResult<Connectrpc_Conformance_V1_ClientStreamResponse>) -> Void) -> any Connect.ClientOnlyStreamInterface<Connectrpc_Conformance_V1_ClientStreamRequest> {
        return self.client.clientOnlyStream(path: "/connectrpc.conformance.v1.ConformanceService/ClientStream", headers: headers, onResult: onResult)
    }

    @available(iOS 13, *)
    internal func `clientStream`(headers: Connect.Headers = [:]) -> any Connect.ClientOnlyAsyncStreamInterface<Connectrpc_Conformance_V1_ClientStreamRequest, Connectrpc_Conformance_V1_ClientStreamResponse> {
        return self.client.clientOnlyStream(path: "/connectrpc.conformance.v1.ConformanceService/ClientStream", headers: headers)
    }

    internal func `bidiStream`(headers: Connect.Headers = [:], onResult: @escaping @Sendable (Connect.StreamResult<Connectrpc_Conformance_V1_BidiStreamResponse>) -> Void) -> any Connect.BidirectionalStreamInterface<Connectrpc_Conformance_V1_BidiStreamRequest> {
        return self.client.bidirectionalStream(path: "/connectrpc.conformance.v1.ConformanceService/BidiStream", headers: headers, onResult: onResult)
    }

    @available(iOS 13, *)
    internal func `bidiStream`(headers: Connect.Headers = [:]) -> any Connect.BidirectionalAsyncStreamInterface<Connectrpc_Conformance_V1_BidiStreamRequest, Connectrpc_Conformance_V1_BidiStreamResponse> {
        return self.client.bidirectionalStream(path: "/connectrpc.conformance.v1.ConformanceService/BidiStream", headers: headers)
    }

    @discardableResult
    internal func `unimplemented`(request: Connectrpc_Conformance_V1_UnimplementedRequest, headers: Connect.Headers = [:], completion: @escaping @Sendable (ResponseMessage<Connectrpc_Conformance_V1_UnimplementedResponse>) -> Void) -> Connect.Cancelable {
        return self.client.unary(path: "/connectrpc.conformance.v1.ConformanceService/Unimplemented", idempotencyLevel: .unknown, request: request, headers: headers, completion: completion)
    }

    @available(iOS 13, *)
    internal func `unimplemented`(request: Connectrpc_Conformance_V1_UnimplementedRequest, headers: Connect.Headers = [:]) async -> ResponseMessage<Connectrpc_Conformance_V1_UnimplementedResponse> {
        return await self.client.unary(path: "/connectrpc.conformance.v1.ConformanceService/Unimplemented", idempotencyLevel: .unknown, request: request, headers: headers)
    }

    @discardableResult
    internal func `idempotentUnary`(request: Connectrpc_Conformance_V1_IdempotentUnaryRequest, headers: Connect.Headers = [:], completion: @escaping @Sendable (ResponseMessage<Connectrpc_Conformance_V1_IdempotentUnaryResponse>) -> Void) -> Connect.Cancelable {
        return self.client.unary(path: "/connectrpc.conformance.v1.ConformanceService/IdempotentUnary", idempotencyLevel: .noSideEffects, request: request, headers: headers, completion: completion)
    }

    @available(iOS 13, *)
    internal func `idempotentUnary`(request: Connectrpc_Conformance_V1_IdempotentUnaryRequest, headers: Connect.Headers = [:]) async -> ResponseMessage<Connectrpc_Conformance_V1_IdempotentUnaryResponse> {
        return await self.client.unary(path: "/connectrpc.conformance.v1.ConformanceService/IdempotentUnary", idempotencyLevel: .noSideEffects, request: request, headers: headers)
    }

    internal enum Metadata {
        internal enum Methods {
            internal static let unary = Connect.MethodSpec(name: "Unary", service: "connectrpc.conformance.v1.ConformanceService", type: .unary)
            internal static let serverStream = Connect.MethodSpec(name: "ServerStream", service: "connectrpc.conformance.v1.ConformanceService", type: .serverStream)
            internal static let clientStream = Connect.MethodSpec(name: "ClientStream", service: "connectrpc.conformance.v1.ConformanceService", type: .clientStream)
            internal static let bidiStream = Connect.MethodSpec(name: "BidiStream", service: "connectrpc.conformance.v1.ConformanceService", type: .bidirectionalStream)
            internal static let unimplemented = Connect.MethodSpec(name: "Unimplemented", service: "connectrpc.conformance.v1.ConformanceService", type: .unary)
            internal static let idempotentUnary = Connect.MethodSpec(name: "IdempotentUnary", service: "connectrpc.conformance.v1.ConformanceService", type: .unary)
        }
    }
}
