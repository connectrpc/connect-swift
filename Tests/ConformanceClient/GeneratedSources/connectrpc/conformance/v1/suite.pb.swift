// DO NOT EDIT.
// swift-format-ignore-file
// swiftlint:disable all
//
// Generated by the Swift generator plugin for the protocol buffer compiler.
// Source: connectrpc/conformance/v1/suite.proto
//
// For information on using the generated types, please see the documentation:
//   https://github.com/apple/swift-protobuf/

// Copyright 2023-2024 The Connect Authors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import SwiftProtobuf

// If the compiler emits an error on this type, it is because this file
// was generated by a version of the `protoc` Swift plug-in that is
// incompatible with the version of SwiftProtobuf to which you are linking.
// Please ensure that you are building against the same version of the API
// that was used to generate this file.
fileprivate struct _GeneratedWithProtocGenSwiftVersion: SwiftProtobuf.ProtobufAPIVersionCheck {
  struct _2: SwiftProtobuf.ProtobufAPIVersion_2 {}
  typealias Version = _2
}

/// TestSuite represents a set of conformance test cases. This is also the schema
/// used for the structure of a YAML test file. Each YAML file represents a test
/// suite, which can contain numerous cases. Each test suite has various properties
/// that indicate the kinds of features that are tested. Test suites may be skipped
/// based on whether the client or server under test implements these features.
struct Connectrpc_Conformance_V1_TestSuite: Sendable {
  // SwiftProtobuf.Message conformance is added in an extension below. See the
  // `Message` and `Message+*Additions` files in the SwiftProtobuf library for
  // methods supported on all messages.

  /// Test suite name. When writing test suites, this is a required field.
  var name: String = String()

  /// The mode (client or server) that this test suite applies to. This is used
  /// in conjunction with the `--mode` flag passed to the conformance runner
  /// binary. If the mode on the suite is set to client, the tests will only be
  /// run if `--mode client` is set on the command to the test runner.
  /// Likewise if mode is server. If this is unset, the test case will be run in both modes.
  var mode: Connectrpc_Conformance_V1_TestSuite.TestMode = .unspecified

  /// The actual test cases in the suite.
  var testCases: [Connectrpc_Conformance_V1_TestCase] = []

  /// If non-empty, the protocols to which this suite applies. If empty,
  /// this suite applies to all protocols.
  var relevantProtocols: [Connectrpc_Conformance_V1_Protocol] = []

  /// If non-empty, the HTTP versions to which this suite applies. If empty,
  /// this suite applies to all HTTP versions.
  var relevantHTTPVersions: [Connectrpc_Conformance_V1_HTTPVersion] = []

  /// If non-empty, the codecs to which this suite applies. If empty, this
  /// suite applies to all codecs.
  var relevantCodecs: [Connectrpc_Conformance_V1_Codec] = []

  /// If non-empty, the compression encodings to which this suite applies.
  /// If empty, this suite applies to all encodings.
  var relevantCompressions: [Connectrpc_Conformance_V1_Compression] = []

  /// Indicates the Connect version validation behavior that this suite
  /// relies on.
  var connectVersionMode: Connectrpc_Conformance_V1_TestSuite.ConnectVersionMode = .unspecified

  /// If true, the cases in this suite rely on TLS and will only be run against
  /// TLS server configurations.
  var reliesOnTls: Bool = false

  /// If true, the cases in this suite rely on the client using TLS
  /// certificates to authenticate with the server. (Should only be
  /// true if relies_on_tls is also true.)
  var reliesOnTlsClientCerts: Bool = false

  /// If true, the cases in this suite rely on the Connect GET protocol.
  var reliesOnConnectGet: Bool = false

  /// If true, the cases in this suite rely on support for limiting the
  /// size of received messages. When true, mode should be set to indicate
  /// whether it is the client or the server that must support the limit.
  var reliesOnMessageReceiveLimit: Bool = false

  var unknownFields = SwiftProtobuf.UnknownStorage()

  enum TestMode: SwiftProtobuf.Enum, Swift.CaseIterable {
    typealias RawValue = Int

    /// Used when the test suite does not apply to a particular mode. Such tests
    /// are run, regardless of the current test mode, to verify both clients and
    /// servers under test.
    case unspecified // = 0

    /// Indicates tests that are intended to be used only for a client-under-test.
    /// These cases can induce very particular and/or aberrant responses from the
    /// reference server, to verify how the client reacts to such responses.
    case client // = 1

    /// Indicates tests that are intended to be used only for a server-under-test.
    /// These cases can induce very particular and/or aberrant requests from the
    /// reference client, to verify how the server reacts to such requests.
    case server // = 2
    case UNRECOGNIZED(Int)

    init() {
      self = .unspecified
    }

    init?(rawValue: Int) {
      switch rawValue {
      case 0: self = .unspecified
      case 1: self = .client
      case 2: self = .server
      default: self = .UNRECOGNIZED(rawValue)
      }
    }

    var rawValue: Int {
      switch self {
      case .unspecified: return 0
      case .client: return 1
      case .server: return 2
      case .UNRECOGNIZED(let i): return i
      }
    }

    // The compiler won't synthesize support with the UNRECOGNIZED case.
    static let allCases: [Connectrpc_Conformance_V1_TestSuite.TestMode] = [
      .unspecified,
      .client,
      .server,
    ]

  }

  enum ConnectVersionMode: SwiftProtobuf.Enum, Swift.CaseIterable {
    typealias RawValue = Int

    /// Used when the suite is agnostic to the server's validation
    /// behavior.
    case unspecified // = 0

    /// Used when the suite relies on the server validating the presence
    /// and correctness of the Connect version header or query param.
    case require // = 1

    /// Used when the suite relies on the server ignore any Connect
    /// header or query param.
    case ignore // = 2
    case UNRECOGNIZED(Int)

    init() {
      self = .unspecified
    }

    init?(rawValue: Int) {
      switch rawValue {
      case 0: self = .unspecified
      case 1: self = .require
      case 2: self = .ignore
      default: self = .UNRECOGNIZED(rawValue)
      }
    }

    var rawValue: Int {
      switch self {
      case .unspecified: return 0
      case .require: return 1
      case .ignore: return 2
      case .UNRECOGNIZED(let i): return i
      }
    }

    // The compiler won't synthesize support with the UNRECOGNIZED case.
    static let allCases: [Connectrpc_Conformance_V1_TestSuite.ConnectVersionMode] = [
      .unspecified,
      .require,
      .ignore,
    ]

  }

  init() {}
}

struct Connectrpc_Conformance_V1_TestCase: Sendable {
  // SwiftProtobuf.Message conformance is added in an extension below. See the
  // `Message` and `Message+*Additions` files in the SwiftProtobuf library for
  // methods supported on all messages.

  /// Defines the RPC that the client should invoke. The first eight fields
  /// are not fully specified. Instead the first field, test_name, must be
  /// present but is a prefix -- other characteristics that identify one
  /// permutation of the test case will be appended to this name. The next
  /// seven fields (http_version, protocol, codec, compression, host, port,
  /// and server_tls_cert) must not be present. They are all populated by
  /// the test harness based on the test environment (e.g. actual server and
  ///  port to use) and characteristics of a single permutation.
  var request: Connectrpc_Conformance_V1_ClientCompatRequest {
    get {return _request ?? Connectrpc_Conformance_V1_ClientCompatRequest()}
    set {_request = newValue}
  }
  /// Returns true if `request` has been explicitly set.
  var hasRequest: Bool {return self._request != nil}
  /// Clears the value of `request`. Subsequent reads from it will return its default value.
  mutating func clearRequest() {self._request = nil}

  /// To support extremely large messages, as well as very precisely-sized
  /// messages, without having to encode them fully or perfectly in YAML
  /// test cases, this value can be specified. When non-empty, this value
  /// should have no more entries than there are messages in the request
  /// stream. The first value is applied to the first request message, and
  /// so on. For each entry, if the size is present, it is used to expand
  /// the data field in the request (which is actually part of the response
  /// definition). The specified size is added to the current limit on
  /// message size that the server will accept. That sum is the size of the
  /// the serialized message that will be sent, and the data field will be
  /// padded as needed to reach that size.
  var expandRequests: [Connectrpc_Conformance_V1_TestCase.ExpandedSize] = []

  /// Defines the expected response to the above RPC. The expected response for
  /// a test is auto-generated based on the request details. The conformance runner
  /// will determine what the response should be according to the values specified
  /// in the test suite and individual test cases.
  ///
  /// This value can also be specified explicitly in the test case YAML. However,
  /// this is typically only needed for exception test cases. If the expected
  /// response is mostly re-stating the response definition that appears in the
  /// requests, test cases should rely on the auto-generation if possible.
  /// Otherwise, specifying an expected response can make the test YAML overly
  /// verbose and harder to read, write, and maintain.
  ///
  /// If the test induces behavior that prevents the server from sending or client
  /// from receiving the full response definition, it will be necessary to define
  /// the expected response explicitly. Timeouts, cancellations, and exceeding
  /// message size limits are good examples of this.
  ///
  /// Specifying an expected response explicitly in test definitions will override
  /// the auto-generation of the test runner.
  var expectedResponse: Connectrpc_Conformance_V1_ClientResponseResult {
    get {return _expectedResponse ?? Connectrpc_Conformance_V1_ClientResponseResult()}
    set {_expectedResponse = newValue}
  }
  /// Returns true if `expectedResponse` has been explicitly set.
  var hasExpectedResponse: Bool {return self._expectedResponse != nil}
  /// Clears the value of `expectedResponse`. Subsequent reads from it will return its default value.
  mutating func clearExpectedResponse() {self._expectedResponse = nil}

  /// When expected_response indicates that an error is expected, in some cases, the
  /// actual error code returned may be flexible. In that case, this field provides
  /// other acceptable error codes, in addition to the one indicated in the
  /// expected_response. As long as the actual error's code matches any of these, the
  /// error is considered conformant, and the test case can pass.
  var otherAllowedErrorCodes: [Connectrpc_Conformance_V1_Code] = []

  var unknownFields = SwiftProtobuf.UnknownStorage()

  struct ExpandedSize: Sendable {
    // SwiftProtobuf.Message conformance is added in an extension below. See the
    // `Message` and `Message+*Additions` files in the SwiftProtobuf library for
    // methods supported on all messages.

    /// The size, in bytes, relative to the limit. For example, to expand to a
    /// size that is exactly equal to the limit, this should be set to zero.
    /// Any value greater than zero indicates that the request size will be that
    /// many bytes over the limit.
    var sizeRelativeToLimit: Int32 {
      get {return _sizeRelativeToLimit ?? 0}
      set {_sizeRelativeToLimit = newValue}
    }
    /// Returns true if `sizeRelativeToLimit` has been explicitly set.
    var hasSizeRelativeToLimit: Bool {return self._sizeRelativeToLimit != nil}
    /// Clears the value of `sizeRelativeToLimit`. Subsequent reads from it will return its default value.
    mutating func clearSizeRelativeToLimit() {self._sizeRelativeToLimit = nil}

    var unknownFields = SwiftProtobuf.UnknownStorage()

    init() {}

    fileprivate var _sizeRelativeToLimit: Int32? = nil
  }

  init() {}

  fileprivate var _request: Connectrpc_Conformance_V1_ClientCompatRequest? = nil
  fileprivate var _expectedResponse: Connectrpc_Conformance_V1_ClientResponseResult? = nil
}

// MARK: - Code below here is support for the SwiftProtobuf runtime.

fileprivate let _protobuf_package = "connectrpc.conformance.v1"

extension Connectrpc_Conformance_V1_TestSuite: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
  static let protoMessageName: String = _protobuf_package + ".TestSuite"
  static let _protobuf_nameMap: SwiftProtobuf._NameMap = [
    1: .same(proto: "name"),
    2: .same(proto: "mode"),
    3: .standard(proto: "test_cases"),
    4: .standard(proto: "relevant_protocols"),
    5: .standard(proto: "relevant_http_versions"),
    6: .standard(proto: "relevant_codecs"),
    7: .standard(proto: "relevant_compressions"),
    8: .standard(proto: "connect_version_mode"),
    9: .standard(proto: "relies_on_tls"),
    10: .standard(proto: "relies_on_tls_client_certs"),
    11: .standard(proto: "relies_on_connect_get"),
    12: .standard(proto: "relies_on_message_receive_limit"),
  ]

  mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
    while let fieldNumber = try decoder.nextFieldNumber() {
      // The use of inline closures is to circumvent an issue where the compiler
      // allocates stack space for every case branch when no optimizations are
      // enabled. https://github.com/apple/swift-protobuf/issues/1034
      switch fieldNumber {
      case 1: try { try decoder.decodeSingularStringField(value: &self.name) }()
      case 2: try { try decoder.decodeSingularEnumField(value: &self.mode) }()
      case 3: try { try decoder.decodeRepeatedMessageField(value: &self.testCases) }()
      case 4: try { try decoder.decodeRepeatedEnumField(value: &self.relevantProtocols) }()
      case 5: try { try decoder.decodeRepeatedEnumField(value: &self.relevantHTTPVersions) }()
      case 6: try { try decoder.decodeRepeatedEnumField(value: &self.relevantCodecs) }()
      case 7: try { try decoder.decodeRepeatedEnumField(value: &self.relevantCompressions) }()
      case 8: try { try decoder.decodeSingularEnumField(value: &self.connectVersionMode) }()
      case 9: try { try decoder.decodeSingularBoolField(value: &self.reliesOnTls) }()
      case 10: try { try decoder.decodeSingularBoolField(value: &self.reliesOnTlsClientCerts) }()
      case 11: try { try decoder.decodeSingularBoolField(value: &self.reliesOnConnectGet) }()
      case 12: try { try decoder.decodeSingularBoolField(value: &self.reliesOnMessageReceiveLimit) }()
      default: break
      }
    }
  }

  func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
    if !self.name.isEmpty {
      try visitor.visitSingularStringField(value: self.name, fieldNumber: 1)
    }
    if self.mode != .unspecified {
      try visitor.visitSingularEnumField(value: self.mode, fieldNumber: 2)
    }
    if !self.testCases.isEmpty {
      try visitor.visitRepeatedMessageField(value: self.testCases, fieldNumber: 3)
    }
    if !self.relevantProtocols.isEmpty {
      try visitor.visitPackedEnumField(value: self.relevantProtocols, fieldNumber: 4)
    }
    if !self.relevantHTTPVersions.isEmpty {
      try visitor.visitPackedEnumField(value: self.relevantHTTPVersions, fieldNumber: 5)
    }
    if !self.relevantCodecs.isEmpty {
      try visitor.visitPackedEnumField(value: self.relevantCodecs, fieldNumber: 6)
    }
    if !self.relevantCompressions.isEmpty {
      try visitor.visitPackedEnumField(value: self.relevantCompressions, fieldNumber: 7)
    }
    if self.connectVersionMode != .unspecified {
      try visitor.visitSingularEnumField(value: self.connectVersionMode, fieldNumber: 8)
    }
    if self.reliesOnTls != false {
      try visitor.visitSingularBoolField(value: self.reliesOnTls, fieldNumber: 9)
    }
    if self.reliesOnTlsClientCerts != false {
      try visitor.visitSingularBoolField(value: self.reliesOnTlsClientCerts, fieldNumber: 10)
    }
    if self.reliesOnConnectGet != false {
      try visitor.visitSingularBoolField(value: self.reliesOnConnectGet, fieldNumber: 11)
    }
    if self.reliesOnMessageReceiveLimit != false {
      try visitor.visitSingularBoolField(value: self.reliesOnMessageReceiveLimit, fieldNumber: 12)
    }
    try unknownFields.traverse(visitor: &visitor)
  }

  static func ==(lhs: Connectrpc_Conformance_V1_TestSuite, rhs: Connectrpc_Conformance_V1_TestSuite) -> Bool {
    if lhs.name != rhs.name {return false}
    if lhs.mode != rhs.mode {return false}
    if lhs.testCases != rhs.testCases {return false}
    if lhs.relevantProtocols != rhs.relevantProtocols {return false}
    if lhs.relevantHTTPVersions != rhs.relevantHTTPVersions {return false}
    if lhs.relevantCodecs != rhs.relevantCodecs {return false}
    if lhs.relevantCompressions != rhs.relevantCompressions {return false}
    if lhs.connectVersionMode != rhs.connectVersionMode {return false}
    if lhs.reliesOnTls != rhs.reliesOnTls {return false}
    if lhs.reliesOnTlsClientCerts != rhs.reliesOnTlsClientCerts {return false}
    if lhs.reliesOnConnectGet != rhs.reliesOnConnectGet {return false}
    if lhs.reliesOnMessageReceiveLimit != rhs.reliesOnMessageReceiveLimit {return false}
    if lhs.unknownFields != rhs.unknownFields {return false}
    return true
  }
}

extension Connectrpc_Conformance_V1_TestSuite.TestMode: SwiftProtobuf._ProtoNameProviding {
  static let _protobuf_nameMap: SwiftProtobuf._NameMap = [
    0: .same(proto: "TEST_MODE_UNSPECIFIED"),
    1: .same(proto: "TEST_MODE_CLIENT"),
    2: .same(proto: "TEST_MODE_SERVER"),
  ]
}

extension Connectrpc_Conformance_V1_TestSuite.ConnectVersionMode: SwiftProtobuf._ProtoNameProviding {
  static let _protobuf_nameMap: SwiftProtobuf._NameMap = [
    0: .same(proto: "CONNECT_VERSION_MODE_UNSPECIFIED"),
    1: .same(proto: "CONNECT_VERSION_MODE_REQUIRE"),
    2: .same(proto: "CONNECT_VERSION_MODE_IGNORE"),
  ]
}

extension Connectrpc_Conformance_V1_TestCase: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
  static let protoMessageName: String = _protobuf_package + ".TestCase"
  static let _protobuf_nameMap: SwiftProtobuf._NameMap = [
    1: .same(proto: "request"),
    2: .standard(proto: "expand_requests"),
    3: .standard(proto: "expected_response"),
    4: .standard(proto: "other_allowed_error_codes"),
  ]

  mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
    while let fieldNumber = try decoder.nextFieldNumber() {
      // The use of inline closures is to circumvent an issue where the compiler
      // allocates stack space for every case branch when no optimizations are
      // enabled. https://github.com/apple/swift-protobuf/issues/1034
      switch fieldNumber {
      case 1: try { try decoder.decodeSingularMessageField(value: &self._request) }()
      case 2: try { try decoder.decodeRepeatedMessageField(value: &self.expandRequests) }()
      case 3: try { try decoder.decodeSingularMessageField(value: &self._expectedResponse) }()
      case 4: try { try decoder.decodeRepeatedEnumField(value: &self.otherAllowedErrorCodes) }()
      default: break
      }
    }
  }

  func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
    // The use of inline closures is to circumvent an issue where the compiler
    // allocates stack space for every if/case branch local when no optimizations
    // are enabled. https://github.com/apple/swift-protobuf/issues/1034 and
    // https://github.com/apple/swift-protobuf/issues/1182
    try { if let v = self._request {
      try visitor.visitSingularMessageField(value: v, fieldNumber: 1)
    } }()
    if !self.expandRequests.isEmpty {
      try visitor.visitRepeatedMessageField(value: self.expandRequests, fieldNumber: 2)
    }
    try { if let v = self._expectedResponse {
      try visitor.visitSingularMessageField(value: v, fieldNumber: 3)
    } }()
    if !self.otherAllowedErrorCodes.isEmpty {
      try visitor.visitPackedEnumField(value: self.otherAllowedErrorCodes, fieldNumber: 4)
    }
    try unknownFields.traverse(visitor: &visitor)
  }

  static func ==(lhs: Connectrpc_Conformance_V1_TestCase, rhs: Connectrpc_Conformance_V1_TestCase) -> Bool {
    if lhs._request != rhs._request {return false}
    if lhs.expandRequests != rhs.expandRequests {return false}
    if lhs._expectedResponse != rhs._expectedResponse {return false}
    if lhs.otherAllowedErrorCodes != rhs.otherAllowedErrorCodes {return false}
    if lhs.unknownFields != rhs.unknownFields {return false}
    return true
  }
}

extension Connectrpc_Conformance_V1_TestCase.ExpandedSize: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
  static let protoMessageName: String = Connectrpc_Conformance_V1_TestCase.protoMessageName + ".ExpandedSize"
  static let _protobuf_nameMap: SwiftProtobuf._NameMap = [
    1: .standard(proto: "size_relative_to_limit"),
  ]

  mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
    while let fieldNumber = try decoder.nextFieldNumber() {
      // The use of inline closures is to circumvent an issue where the compiler
      // allocates stack space for every case branch when no optimizations are
      // enabled. https://github.com/apple/swift-protobuf/issues/1034
      switch fieldNumber {
      case 1: try { try decoder.decodeSingularInt32Field(value: &self._sizeRelativeToLimit) }()
      default: break
      }
    }
  }

  func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
    // The use of inline closures is to circumvent an issue where the compiler
    // allocates stack space for every if/case branch local when no optimizations
    // are enabled. https://github.com/apple/swift-protobuf/issues/1034 and
    // https://github.com/apple/swift-protobuf/issues/1182
    try { if let v = self._sizeRelativeToLimit {
      try visitor.visitSingularInt32Field(value: v, fieldNumber: 1)
    } }()
    try unknownFields.traverse(visitor: &visitor)
  }

  static func ==(lhs: Connectrpc_Conformance_V1_TestCase.ExpandedSize, rhs: Connectrpc_Conformance_V1_TestCase.ExpandedSize) -> Bool {
    if lhs._sizeRelativeToLimit != rhs._sizeRelativeToLimit {return false}
    if lhs.unknownFields != rhs.unknownFields {return false}
    return true
  }
}
