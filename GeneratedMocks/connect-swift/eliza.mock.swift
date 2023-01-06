// Code generated by protoc-gen-connect-swift. DO NOT EDIT.
//
// Source: eliza.proto
//

import Combine
import Connect
import ConnectMocks
import Foundation
import Generated
import SwiftProtobuf

/// Mock implementation of `Buf_Connect_Demo_Eliza_V1_ElizaServiceClientInterface`.
///
/// Production implementations can be substituted with instances of this
/// class, allowing for mocking RPC calls. Behavior can be customized
/// either through the properties on this class or by
/// subclassing the class and overriding its methods.
open class Buf_Connect_Demo_Eliza_V1_ElizaServiceClientMock: Buf_Connect_Demo_Eliza_V1_ElizaServiceClientInterface {
    private var cancellables = [Combine.AnyCancellable]()

    /// Mocked for calls to `say()`.
    public var mockSay = { (_: Buf_Connect_Demo_Eliza_V1_SayRequest) -> Result<ResponseMessage<Buf_Connect_Demo_Eliza_V1_SayResponse>, ConnectError> in .success(.init(message: .init())) }
    /// Mocked for async calls to `say()`.
    public var mockAsyncSay = { (_: Buf_Connect_Demo_Eliza_V1_SayRequest) -> Result<ResponseMessage<Buf_Connect_Demo_Eliza_V1_SayResponse>, ConnectError> in .success(.init(message: .init())) }
    /// Mocked for calls to `converse()`.
    public var mockConverse = MockBidirectionalStream<Buf_Connect_Demo_Eliza_V1_ConverseRequest, Buf_Connect_Demo_Eliza_V1_ConverseResponse>()
    /// Mocked for async calls to `converse()`.
    public var mockAsyncConverse = MockBidirectionalAsyncStream<Buf_Connect_Demo_Eliza_V1_ConverseRequest, Buf_Connect_Demo_Eliza_V1_ConverseResponse>()
    /// Mocked for calls to `introduce()`.
    public var mockIntroduce = MockServerOnlyStream<Buf_Connect_Demo_Eliza_V1_IntroduceRequest, Buf_Connect_Demo_Eliza_V1_IntroduceResponse>()
    /// Mocked for async calls to `introduce()`.
    public var mockAsyncIntroduce = MockServerOnlyAsyncStream<Buf_Connect_Demo_Eliza_V1_IntroduceRequest, Buf_Connect_Demo_Eliza_V1_IntroduceResponse>()

    public init() {}

    @discardableResult
    open func `say`(request: Buf_Connect_Demo_Eliza_V1_SayRequest, headers: Connect.Headers = [:], completion: @escaping (Swift.Result<ResponseMessage<Buf_Connect_Demo_Eliza_V1_SayResponse>, Connect.ConnectError>) -> Void) -> Connect.Cancelable {
        completion(self.mockSay(request))
        return Connect.Cancelable {}
    }

    @discardableResult
    open func `say`(request: Buf_Connect_Demo_Eliza_V1_SayRequest, headers: Connect.Headers = [:]) async -> Swift.Result<ResponseMessage<Buf_Connect_Demo_Eliza_V1_SayResponse>, Connect.ConnectError> {
        return self.mockAsyncSay(request)
    }

    open func `converse`(headers: Connect.Headers = [:], onResult: @escaping (Connect.StreamResult<Buf_Connect_Demo_Eliza_V1_ConverseResponse>) -> Void) -> any Connect.BidirectionalStreamInterface<Buf_Connect_Demo_Eliza_V1_ConverseRequest> {
        self.mockConverse.$inputs.first { !$0.isEmpty }.sink { _ in self.mockConverse.outputs.forEach(onResult) }.store(in: &self.cancellables)
        return self.mockConverse
    }

    open func `converse`(headers: Connect.Headers = [:]) -> any Connect.BidirectionalAsyncStreamInterface<Buf_Connect_Demo_Eliza_V1_ConverseRequest, Buf_Connect_Demo_Eliza_V1_ConverseResponse> {
        return self.mockAsyncConverse
    }

    open func `introduce`(headers: Connect.Headers = [:], onResult: @escaping (Connect.StreamResult<Buf_Connect_Demo_Eliza_V1_IntroduceResponse>) -> Void) -> any Connect.ServerOnlyStreamInterface<Buf_Connect_Demo_Eliza_V1_IntroduceRequest> {
        self.mockIntroduce.$inputs.first { !$0.isEmpty }.sink { _ in self.mockIntroduce.outputs.forEach(onResult) }.store(in: &self.cancellables)
        return self.mockIntroduce
    }

    open func `introduce`(headers: Connect.Headers = [:]) -> any Connect.ServerOnlyAsyncStreamInterface<Buf_Connect_Demo_Eliza_V1_IntroduceRequest, Buf_Connect_Demo_Eliza_V1_IntroduceResponse> {
        return self.mockAsyncIntroduce
    }
}
