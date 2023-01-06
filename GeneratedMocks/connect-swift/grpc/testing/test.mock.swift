// Code generated by protoc-gen-connect-swift. DO NOT EDIT.
//
// Source: grpc/testing/test.proto
//

import Combine
import Connect
import ConnectMocks
import Foundation
import Generated
import SwiftProtobuf

/// Mock implementation of `Grpc_Testing_TestServiceClientInterface`.
///
/// Production implementations can be substituted with instances of this
/// class, allowing for mocking RPC calls. Behavior can be customized
/// either through the properties on this class or by
/// subclassing the class and overriding its methods.
open class Grpc_Testing_TestServiceClientMock: Grpc_Testing_TestServiceClientInterface {
    private var cancellables = [Combine.AnyCancellable]()

    /// Mocked for calls to `emptyCall()`.
    public var mockEmptyCall = { (_: Grpc_Testing_Empty) -> Result<ResponseMessage<Grpc_Testing_Empty>, ConnectError> in .success(.init(message: .init())) }
    /// Mocked for async calls to `emptyCall()`.
    public var mockAsyncEmptyCall = { (_: Grpc_Testing_Empty) -> Result<ResponseMessage<Grpc_Testing_Empty>, ConnectError> in .success(.init(message: .init())) }
    /// Mocked for calls to `unaryCall()`.
    public var mockUnaryCall = { (_: Grpc_Testing_SimpleRequest) -> Result<ResponseMessage<Grpc_Testing_SimpleResponse>, ConnectError> in .success(.init(message: .init())) }
    /// Mocked for async calls to `unaryCall()`.
    public var mockAsyncUnaryCall = { (_: Grpc_Testing_SimpleRequest) -> Result<ResponseMessage<Grpc_Testing_SimpleResponse>, ConnectError> in .success(.init(message: .init())) }
    /// Mocked for calls to `failUnaryCall()`.
    public var mockFailUnaryCall = { (_: Grpc_Testing_SimpleRequest) -> Result<ResponseMessage<Grpc_Testing_SimpleResponse>, ConnectError> in .success(.init(message: .init())) }
    /// Mocked for async calls to `failUnaryCall()`.
    public var mockAsyncFailUnaryCall = { (_: Grpc_Testing_SimpleRequest) -> Result<ResponseMessage<Grpc_Testing_SimpleResponse>, ConnectError> in .success(.init(message: .init())) }
    /// Mocked for calls to `cacheableUnaryCall()`.
    public var mockCacheableUnaryCall = { (_: Grpc_Testing_SimpleRequest) -> Result<ResponseMessage<Grpc_Testing_SimpleResponse>, ConnectError> in .success(.init(message: .init())) }
    /// Mocked for async calls to `cacheableUnaryCall()`.
    public var mockAsyncCacheableUnaryCall = { (_: Grpc_Testing_SimpleRequest) -> Result<ResponseMessage<Grpc_Testing_SimpleResponse>, ConnectError> in .success(.init(message: .init())) }
    /// Mocked for calls to `streamingOutputCall()`.
    public var mockStreamingOutputCall = MockServerOnlyStream<Grpc_Testing_StreamingOutputCallRequest, Grpc_Testing_StreamingOutputCallResponse>()
    /// Mocked for async calls to `streamingOutputCall()`.
    public var mockAsyncStreamingOutputCall = MockServerOnlyAsyncStream<Grpc_Testing_StreamingOutputCallRequest, Grpc_Testing_StreamingOutputCallResponse>()
    /// Mocked for calls to `failStreamingOutputCall()`.
    public var mockFailStreamingOutputCall = MockServerOnlyStream<Grpc_Testing_StreamingOutputCallRequest, Grpc_Testing_StreamingOutputCallResponse>()
    /// Mocked for async calls to `failStreamingOutputCall()`.
    public var mockAsyncFailStreamingOutputCall = MockServerOnlyAsyncStream<Grpc_Testing_StreamingOutputCallRequest, Grpc_Testing_StreamingOutputCallResponse>()
    /// Mocked for calls to `streamingInputCall()`.
    public var mockStreamingInputCall = MockClientOnlyStream<Grpc_Testing_StreamingInputCallRequest, Grpc_Testing_StreamingInputCallResponse>()
    /// Mocked for async calls to `streamingInputCall()`.
    public var mockAsyncStreamingInputCall = MockClientOnlyAsyncStream<Grpc_Testing_StreamingInputCallRequest, Grpc_Testing_StreamingInputCallResponse>()
    /// Mocked for calls to `fullDuplexCall()`.
    public var mockFullDuplexCall = MockBidirectionalStream<Grpc_Testing_StreamingOutputCallRequest, Grpc_Testing_StreamingOutputCallResponse>()
    /// Mocked for async calls to `fullDuplexCall()`.
    public var mockAsyncFullDuplexCall = MockBidirectionalAsyncStream<Grpc_Testing_StreamingOutputCallRequest, Grpc_Testing_StreamingOutputCallResponse>()
    /// Mocked for calls to `halfDuplexCall()`.
    public var mockHalfDuplexCall = MockBidirectionalStream<Grpc_Testing_StreamingOutputCallRequest, Grpc_Testing_StreamingOutputCallResponse>()
    /// Mocked for async calls to `halfDuplexCall()`.
    public var mockAsyncHalfDuplexCall = MockBidirectionalAsyncStream<Grpc_Testing_StreamingOutputCallRequest, Grpc_Testing_StreamingOutputCallResponse>()
    /// Mocked for calls to `unimplementedCall()`.
    public var mockUnimplementedCall = { (_: Grpc_Testing_Empty) -> Result<ResponseMessage<Grpc_Testing_Empty>, ConnectError> in .success(.init(message: .init())) }
    /// Mocked for async calls to `unimplementedCall()`.
    public var mockAsyncUnimplementedCall = { (_: Grpc_Testing_Empty) -> Result<ResponseMessage<Grpc_Testing_Empty>, ConnectError> in .success(.init(message: .init())) }
    /// Mocked for calls to `unimplementedStreamingOutputCall()`.
    public var mockUnimplementedStreamingOutputCall = MockServerOnlyStream<Grpc_Testing_Empty, Grpc_Testing_Empty>()
    /// Mocked for async calls to `unimplementedStreamingOutputCall()`.
    public var mockAsyncUnimplementedStreamingOutputCall = MockServerOnlyAsyncStream<Grpc_Testing_Empty, Grpc_Testing_Empty>()

    public init() {}

    @discardableResult
    open func `emptyCall`(request: Grpc_Testing_Empty, headers: Connect.Headers = [:], completion: @escaping (Swift.Result<ResponseMessage<Grpc_Testing_Empty>, Connect.ConnectError>) -> Void) -> Connect.Cancelable {
        completion(self.mockEmptyCall(request))
        return Connect.Cancelable {}
    }

    @discardableResult
    open func `emptyCall`(request: Grpc_Testing_Empty, headers: Connect.Headers = [:]) async -> Swift.Result<ResponseMessage<Grpc_Testing_Empty>, Connect.ConnectError> {
        return self.mockAsyncEmptyCall(request)
    }

    @discardableResult
    open func `unaryCall`(request: Grpc_Testing_SimpleRequest, headers: Connect.Headers = [:], completion: @escaping (Swift.Result<ResponseMessage<Grpc_Testing_SimpleResponse>, Connect.ConnectError>) -> Void) -> Connect.Cancelable {
        completion(self.mockUnaryCall(request))
        return Connect.Cancelable {}
    }

    @discardableResult
    open func `unaryCall`(request: Grpc_Testing_SimpleRequest, headers: Connect.Headers = [:]) async -> Swift.Result<ResponseMessage<Grpc_Testing_SimpleResponse>, Connect.ConnectError> {
        return self.mockAsyncUnaryCall(request)
    }

    @discardableResult
    open func `failUnaryCall`(request: Grpc_Testing_SimpleRequest, headers: Connect.Headers = [:], completion: @escaping (Swift.Result<ResponseMessage<Grpc_Testing_SimpleResponse>, Connect.ConnectError>) -> Void) -> Connect.Cancelable {
        completion(self.mockFailUnaryCall(request))
        return Connect.Cancelable {}
    }

    @discardableResult
    open func `failUnaryCall`(request: Grpc_Testing_SimpleRequest, headers: Connect.Headers = [:]) async -> Swift.Result<ResponseMessage<Grpc_Testing_SimpleResponse>, Connect.ConnectError> {
        return self.mockAsyncFailUnaryCall(request)
    }

    @discardableResult
    open func `cacheableUnaryCall`(request: Grpc_Testing_SimpleRequest, headers: Connect.Headers = [:], completion: @escaping (Swift.Result<ResponseMessage<Grpc_Testing_SimpleResponse>, Connect.ConnectError>) -> Void) -> Connect.Cancelable {
        completion(self.mockCacheableUnaryCall(request))
        return Connect.Cancelable {}
    }

    @discardableResult
    open func `cacheableUnaryCall`(request: Grpc_Testing_SimpleRequest, headers: Connect.Headers = [:]) async -> Swift.Result<ResponseMessage<Grpc_Testing_SimpleResponse>, Connect.ConnectError> {
        return self.mockAsyncCacheableUnaryCall(request)
    }

    open func `streamingOutputCall`(headers: Connect.Headers = [:], onResult: @escaping (Connect.StreamResult<Grpc_Testing_StreamingOutputCallResponse>) -> Void) -> any Connect.ServerOnlyStreamInterface<Grpc_Testing_StreamingOutputCallRequest> {
        self.mockStreamingOutputCall.$inputs.first { !$0.isEmpty }.sink { _ in self.mockStreamingOutputCall.outputs.forEach(onResult) }.store(in: &self.cancellables)
        return self.mockStreamingOutputCall
    }

    open func `streamingOutputCall`(headers: Connect.Headers = [:]) -> any Connect.ServerOnlyAsyncStreamInterface<Grpc_Testing_StreamingOutputCallRequest, Grpc_Testing_StreamingOutputCallResponse> {
        return self.mockAsyncStreamingOutputCall
    }

    open func `failStreamingOutputCall`(headers: Connect.Headers = [:], onResult: @escaping (Connect.StreamResult<Grpc_Testing_StreamingOutputCallResponse>) -> Void) -> any Connect.ServerOnlyStreamInterface<Grpc_Testing_StreamingOutputCallRequest> {
        self.mockFailStreamingOutputCall.$inputs.first { !$0.isEmpty }.sink { _ in self.mockFailStreamingOutputCall.outputs.forEach(onResult) }.store(in: &self.cancellables)
        return self.mockFailStreamingOutputCall
    }

    open func `failStreamingOutputCall`(headers: Connect.Headers = [:]) -> any Connect.ServerOnlyAsyncStreamInterface<Grpc_Testing_StreamingOutputCallRequest, Grpc_Testing_StreamingOutputCallResponse> {
        return self.mockAsyncFailStreamingOutputCall
    }

    open func `streamingInputCall`(headers: Connect.Headers = [:], onResult: @escaping (Connect.StreamResult<Grpc_Testing_StreamingInputCallResponse>) -> Void) -> any Connect.ClientOnlyStreamInterface<Grpc_Testing_StreamingInputCallRequest> {
        self.mockStreamingInputCall.$inputs.first { !$0.isEmpty }.sink { _ in self.mockStreamingInputCall.outputs.forEach(onResult) }.store(in: &self.cancellables)
        return self.mockStreamingInputCall
    }

    open func `streamingInputCall`(headers: Connect.Headers = [:]) -> any Connect.ClientOnlyAsyncStreamInterface<Grpc_Testing_StreamingInputCallRequest, Grpc_Testing_StreamingInputCallResponse> {
        return self.mockAsyncStreamingInputCall
    }

    open func `fullDuplexCall`(headers: Connect.Headers = [:], onResult: @escaping (Connect.StreamResult<Grpc_Testing_StreamingOutputCallResponse>) -> Void) -> any Connect.BidirectionalStreamInterface<Grpc_Testing_StreamingOutputCallRequest> {
        self.mockFullDuplexCall.$inputs.first { !$0.isEmpty }.sink { _ in self.mockFullDuplexCall.outputs.forEach(onResult) }.store(in: &self.cancellables)
        return self.mockFullDuplexCall
    }

    open func `fullDuplexCall`(headers: Connect.Headers = [:]) -> any Connect.BidirectionalAsyncStreamInterface<Grpc_Testing_StreamingOutputCallRequest, Grpc_Testing_StreamingOutputCallResponse> {
        return self.mockAsyncFullDuplexCall
    }

    open func `halfDuplexCall`(headers: Connect.Headers = [:], onResult: @escaping (Connect.StreamResult<Grpc_Testing_StreamingOutputCallResponse>) -> Void) -> any Connect.BidirectionalStreamInterface<Grpc_Testing_StreamingOutputCallRequest> {
        self.mockHalfDuplexCall.$inputs.first { !$0.isEmpty }.sink { _ in self.mockHalfDuplexCall.outputs.forEach(onResult) }.store(in: &self.cancellables)
        return self.mockHalfDuplexCall
    }

    open func `halfDuplexCall`(headers: Connect.Headers = [:]) -> any Connect.BidirectionalAsyncStreamInterface<Grpc_Testing_StreamingOutputCallRequest, Grpc_Testing_StreamingOutputCallResponse> {
        return self.mockAsyncHalfDuplexCall
    }

    @discardableResult
    open func `unimplementedCall`(request: Grpc_Testing_Empty, headers: Connect.Headers = [:], completion: @escaping (Swift.Result<ResponseMessage<Grpc_Testing_Empty>, Connect.ConnectError>) -> Void) -> Connect.Cancelable {
        completion(self.mockUnimplementedCall(request))
        return Connect.Cancelable {}
    }

    @discardableResult
    open func `unimplementedCall`(request: Grpc_Testing_Empty, headers: Connect.Headers = [:]) async -> Swift.Result<ResponseMessage<Grpc_Testing_Empty>, Connect.ConnectError> {
        return self.mockAsyncUnimplementedCall(request)
    }

    open func `unimplementedStreamingOutputCall`(headers: Connect.Headers = [:], onResult: @escaping (Connect.StreamResult<Grpc_Testing_Empty>) -> Void) -> any Connect.ServerOnlyStreamInterface<Grpc_Testing_Empty> {
        self.mockUnimplementedStreamingOutputCall.$inputs.first { !$0.isEmpty }.sink { _ in self.mockUnimplementedStreamingOutputCall.outputs.forEach(onResult) }.store(in: &self.cancellables)
        return self.mockUnimplementedStreamingOutputCall
    }

    open func `unimplementedStreamingOutputCall`(headers: Connect.Headers = [:]) -> any Connect.ServerOnlyAsyncStreamInterface<Grpc_Testing_Empty, Grpc_Testing_Empty> {
        return self.mockAsyncUnimplementedStreamingOutputCall
    }
}

/// Mock implementation of `Grpc_Testing_UnimplementedServiceClientInterface`.
///
/// Production implementations can be substituted with instances of this
/// class, allowing for mocking RPC calls. Behavior can be customized
/// either through the properties on this class or by
/// subclassing the class and overriding its methods.
open class Grpc_Testing_UnimplementedServiceClientMock: Grpc_Testing_UnimplementedServiceClientInterface {
    private var cancellables = [Combine.AnyCancellable]()

    /// Mocked for calls to `unimplementedCall()`.
    public var mockUnimplementedCall = { (_: Grpc_Testing_Empty) -> Result<ResponseMessage<Grpc_Testing_Empty>, ConnectError> in .success(.init(message: .init())) }
    /// Mocked for async calls to `unimplementedCall()`.
    public var mockAsyncUnimplementedCall = { (_: Grpc_Testing_Empty) -> Result<ResponseMessage<Grpc_Testing_Empty>, ConnectError> in .success(.init(message: .init())) }
    /// Mocked for calls to `unimplementedStreamingOutputCall()`.
    public var mockUnimplementedStreamingOutputCall = MockServerOnlyStream<Grpc_Testing_Empty, Grpc_Testing_Empty>()
    /// Mocked for async calls to `unimplementedStreamingOutputCall()`.
    public var mockAsyncUnimplementedStreamingOutputCall = MockServerOnlyAsyncStream<Grpc_Testing_Empty, Grpc_Testing_Empty>()

    public init() {}

    @discardableResult
    open func `unimplementedCall`(request: Grpc_Testing_Empty, headers: Connect.Headers = [:], completion: @escaping (Swift.Result<ResponseMessage<Grpc_Testing_Empty>, Connect.ConnectError>) -> Void) -> Connect.Cancelable {
        completion(self.mockUnimplementedCall(request))
        return Connect.Cancelable {}
    }

    @discardableResult
    open func `unimplementedCall`(request: Grpc_Testing_Empty, headers: Connect.Headers = [:]) async -> Swift.Result<ResponseMessage<Grpc_Testing_Empty>, Connect.ConnectError> {
        return self.mockAsyncUnimplementedCall(request)
    }

    open func `unimplementedStreamingOutputCall`(headers: Connect.Headers = [:], onResult: @escaping (Connect.StreamResult<Grpc_Testing_Empty>) -> Void) -> any Connect.ServerOnlyStreamInterface<Grpc_Testing_Empty> {
        self.mockUnimplementedStreamingOutputCall.$inputs.first { !$0.isEmpty }.sink { _ in self.mockUnimplementedStreamingOutputCall.outputs.forEach(onResult) }.store(in: &self.cancellables)
        return self.mockUnimplementedStreamingOutputCall
    }

    open func `unimplementedStreamingOutputCall`(headers: Connect.Headers = [:]) -> any Connect.ServerOnlyAsyncStreamInterface<Grpc_Testing_Empty, Grpc_Testing_Empty> {
        return self.mockAsyncUnimplementedStreamingOutputCall
    }
}

/// Mock implementation of `Grpc_Testing_ReconnectServiceClientInterface`.
///
/// Production implementations can be substituted with instances of this
/// class, allowing for mocking RPC calls. Behavior can be customized
/// either through the properties on this class or by
/// subclassing the class and overriding its methods.
open class Grpc_Testing_ReconnectServiceClientMock: Grpc_Testing_ReconnectServiceClientInterface {
    private var cancellables = [Combine.AnyCancellable]()

    /// Mocked for calls to `start()`.
    public var mockStart = { (_: Grpc_Testing_ReconnectParams) -> Result<ResponseMessage<Grpc_Testing_Empty>, ConnectError> in .success(.init(message: .init())) }
    /// Mocked for async calls to `start()`.
    public var mockAsyncStart = { (_: Grpc_Testing_ReconnectParams) -> Result<ResponseMessage<Grpc_Testing_Empty>, ConnectError> in .success(.init(message: .init())) }
    /// Mocked for calls to `stop()`.
    public var mockStop = { (_: Grpc_Testing_Empty) -> Result<ResponseMessage<Grpc_Testing_ReconnectInfo>, ConnectError> in .success(.init(message: .init())) }
    /// Mocked for async calls to `stop()`.
    public var mockAsyncStop = { (_: Grpc_Testing_Empty) -> Result<ResponseMessage<Grpc_Testing_ReconnectInfo>, ConnectError> in .success(.init(message: .init())) }

    public init() {}

    @discardableResult
    open func `start`(request: Grpc_Testing_ReconnectParams, headers: Connect.Headers = [:], completion: @escaping (Swift.Result<ResponseMessage<Grpc_Testing_Empty>, Connect.ConnectError>) -> Void) -> Connect.Cancelable {
        completion(self.mockStart(request))
        return Connect.Cancelable {}
    }

    @discardableResult
    open func `start`(request: Grpc_Testing_ReconnectParams, headers: Connect.Headers = [:]) async -> Swift.Result<ResponseMessage<Grpc_Testing_Empty>, Connect.ConnectError> {
        return self.mockAsyncStart(request)
    }

    @discardableResult
    open func `stop`(request: Grpc_Testing_Empty, headers: Connect.Headers = [:], completion: @escaping (Swift.Result<ResponseMessage<Grpc_Testing_ReconnectInfo>, Connect.ConnectError>) -> Void) -> Connect.Cancelable {
        completion(self.mockStop(request))
        return Connect.Cancelable {}
    }

    @discardableResult
    open func `stop`(request: Grpc_Testing_Empty, headers: Connect.Headers = [:]) async -> Swift.Result<ResponseMessage<Grpc_Testing_ReconnectInfo>, Connect.ConnectError> {
        return self.mockAsyncStop(request)
    }
}

/// Mock implementation of `Grpc_Testing_LoadBalancerStatsServiceClientInterface`.
///
/// Production implementations can be substituted with instances of this
/// class, allowing for mocking RPC calls. Behavior can be customized
/// either through the properties on this class or by
/// subclassing the class and overriding its methods.
open class Grpc_Testing_LoadBalancerStatsServiceClientMock: Grpc_Testing_LoadBalancerStatsServiceClientInterface {
    private var cancellables = [Combine.AnyCancellable]()

    /// Mocked for calls to `getClientStats()`.
    public var mockGetClientStats = { (_: Grpc_Testing_LoadBalancerStatsRequest) -> Result<ResponseMessage<Grpc_Testing_LoadBalancerStatsResponse>, ConnectError> in .success(.init(message: .init())) }
    /// Mocked for async calls to `getClientStats()`.
    public var mockAsyncGetClientStats = { (_: Grpc_Testing_LoadBalancerStatsRequest) -> Result<ResponseMessage<Grpc_Testing_LoadBalancerStatsResponse>, ConnectError> in .success(.init(message: .init())) }
    /// Mocked for calls to `getClientAccumulatedStats()`.
    public var mockGetClientAccumulatedStats = { (_: Grpc_Testing_LoadBalancerAccumulatedStatsRequest) -> Result<ResponseMessage<Grpc_Testing_LoadBalancerAccumulatedStatsResponse>, ConnectError> in .success(.init(message: .init())) }
    /// Mocked for async calls to `getClientAccumulatedStats()`.
    public var mockAsyncGetClientAccumulatedStats = { (_: Grpc_Testing_LoadBalancerAccumulatedStatsRequest) -> Result<ResponseMessage<Grpc_Testing_LoadBalancerAccumulatedStatsResponse>, ConnectError> in .success(.init(message: .init())) }

    public init() {}

    @discardableResult
    open func `getClientStats`(request: Grpc_Testing_LoadBalancerStatsRequest, headers: Connect.Headers = [:], completion: @escaping (Swift.Result<ResponseMessage<Grpc_Testing_LoadBalancerStatsResponse>, Connect.ConnectError>) -> Void) -> Connect.Cancelable {
        completion(self.mockGetClientStats(request))
        return Connect.Cancelable {}
    }

    @discardableResult
    open func `getClientStats`(request: Grpc_Testing_LoadBalancerStatsRequest, headers: Connect.Headers = [:]) async -> Swift.Result<ResponseMessage<Grpc_Testing_LoadBalancerStatsResponse>, Connect.ConnectError> {
        return self.mockAsyncGetClientStats(request)
    }

    @discardableResult
    open func `getClientAccumulatedStats`(request: Grpc_Testing_LoadBalancerAccumulatedStatsRequest, headers: Connect.Headers = [:], completion: @escaping (Swift.Result<ResponseMessage<Grpc_Testing_LoadBalancerAccumulatedStatsResponse>, Connect.ConnectError>) -> Void) -> Connect.Cancelable {
        completion(self.mockGetClientAccumulatedStats(request))
        return Connect.Cancelable {}
    }

    @discardableResult
    open func `getClientAccumulatedStats`(request: Grpc_Testing_LoadBalancerAccumulatedStatsRequest, headers: Connect.Headers = [:]) async -> Swift.Result<ResponseMessage<Grpc_Testing_LoadBalancerAccumulatedStatsResponse>, Connect.ConnectError> {
        return self.mockAsyncGetClientAccumulatedStats(request)
    }
}

/// Mock implementation of `Grpc_Testing_XdsUpdateHealthServiceClientInterface`.
///
/// Production implementations can be substituted with instances of this
/// class, allowing for mocking RPC calls. Behavior can be customized
/// either through the properties on this class or by
/// subclassing the class and overriding its methods.
open class Grpc_Testing_XdsUpdateHealthServiceClientMock: Grpc_Testing_XdsUpdateHealthServiceClientInterface {
    private var cancellables = [Combine.AnyCancellable]()

    /// Mocked for calls to `setServing()`.
    public var mockSetServing = { (_: Grpc_Testing_Empty) -> Result<ResponseMessage<Grpc_Testing_Empty>, ConnectError> in .success(.init(message: .init())) }
    /// Mocked for async calls to `setServing()`.
    public var mockAsyncSetServing = { (_: Grpc_Testing_Empty) -> Result<ResponseMessage<Grpc_Testing_Empty>, ConnectError> in .success(.init(message: .init())) }
    /// Mocked for calls to `setNotServing()`.
    public var mockSetNotServing = { (_: Grpc_Testing_Empty) -> Result<ResponseMessage<Grpc_Testing_Empty>, ConnectError> in .success(.init(message: .init())) }
    /// Mocked for async calls to `setNotServing()`.
    public var mockAsyncSetNotServing = { (_: Grpc_Testing_Empty) -> Result<ResponseMessage<Grpc_Testing_Empty>, ConnectError> in .success(.init(message: .init())) }

    public init() {}

    @discardableResult
    open func `setServing`(request: Grpc_Testing_Empty, headers: Connect.Headers = [:], completion: @escaping (Swift.Result<ResponseMessage<Grpc_Testing_Empty>, Connect.ConnectError>) -> Void) -> Connect.Cancelable {
        completion(self.mockSetServing(request))
        return Connect.Cancelable {}
    }

    @discardableResult
    open func `setServing`(request: Grpc_Testing_Empty, headers: Connect.Headers = [:]) async -> Swift.Result<ResponseMessage<Grpc_Testing_Empty>, Connect.ConnectError> {
        return self.mockAsyncSetServing(request)
    }

    @discardableResult
    open func `setNotServing`(request: Grpc_Testing_Empty, headers: Connect.Headers = [:], completion: @escaping (Swift.Result<ResponseMessage<Grpc_Testing_Empty>, Connect.ConnectError>) -> Void) -> Connect.Cancelable {
        completion(self.mockSetNotServing(request))
        return Connect.Cancelable {}
    }

    @discardableResult
    open func `setNotServing`(request: Grpc_Testing_Empty, headers: Connect.Headers = [:]) async -> Swift.Result<ResponseMessage<Grpc_Testing_Empty>, Connect.ConnectError> {
        return self.mockAsyncSetNotServing(request)
    }
}

/// Mock implementation of `Grpc_Testing_XdsUpdateClientConfigureServiceClientInterface`.
///
/// Production implementations can be substituted with instances of this
/// class, allowing for mocking RPC calls. Behavior can be customized
/// either through the properties on this class or by
/// subclassing the class and overriding its methods.
open class Grpc_Testing_XdsUpdateClientConfigureServiceClientMock: Grpc_Testing_XdsUpdateClientConfigureServiceClientInterface {
    private var cancellables = [Combine.AnyCancellable]()

    /// Mocked for calls to `configure()`.
    public var mockConfigure = { (_: Grpc_Testing_ClientConfigureRequest) -> Result<ResponseMessage<Grpc_Testing_ClientConfigureResponse>, ConnectError> in .success(.init(message: .init())) }
    /// Mocked for async calls to `configure()`.
    public var mockAsyncConfigure = { (_: Grpc_Testing_ClientConfigureRequest) -> Result<ResponseMessage<Grpc_Testing_ClientConfigureResponse>, ConnectError> in .success(.init(message: .init())) }

    public init() {}

    @discardableResult
    open func `configure`(request: Grpc_Testing_ClientConfigureRequest, headers: Connect.Headers = [:], completion: @escaping (Swift.Result<ResponseMessage<Grpc_Testing_ClientConfigureResponse>, Connect.ConnectError>) -> Void) -> Connect.Cancelable {
        completion(self.mockConfigure(request))
        return Connect.Cancelable {}
    }

    @discardableResult
    open func `configure`(request: Grpc_Testing_ClientConfigureRequest, headers: Connect.Headers = [:]) async -> Swift.Result<ResponseMessage<Grpc_Testing_ClientConfigureResponse>, Connect.ConnectError> {
        return self.mockAsyncConfigure(request)
    }
}
