Connect-Swift
=============

[![Build](https://github.com/connectrpc/connect-swift/actions/workflows/ci.yaml/badge.svg?branch=main)](https://github.com/connectrpc/connect-swift/actions/workflows/ci.yaml)
[![Version](https://img.shields.io/cocoapods/v/Connect-Swift.svg?style=flat)](https://cocoapods.org/pods/Connect-Swift)
[![Platform](https://img.shields.io/cocoapods/p/Connect-Swift.svg?style=flat)](https://cocoapods.org/pods/Connect-Swift)
[![License](https://img.shields.io/cocoapods/l/Connect-Swift.svg?style=flat)](https://cocoapods.org/pods/Connect-Swift)

Connect-Swift is a small library (<200KB!) that provides support for using
generated,
type-safe, and idiomatic Swift APIs to communicate with your app's servers
using [Protocol Buffers (Protobuf)][protobuf]. It works with the
[Connect][connect-protocol], [gRPC][grpc-protocol], and
[gRPC-Web][grpc-web-protocol] protocols.

Imagine a world where
you don't have to handwrite `Codable` models for REST/JSON endpoints
and you can instead get right to building features by calling a generated
API method that is guaranteed to match the server's modeling. Furthermore,
imagine never having to worry about serialization again, and being able to
easily write tests using generated mocks that conform to the same protocol
that the real implementations do.
[All of this is possible with Connect-Swift][blog].

Given a simple Protobuf schema, Connect-Swift generates idiomatic Swift
protocol interfaces and client implementations:

<details><summary>Click to expand <code>eliza.connect.swift</code></summary>

```swift
public protocol Eliza_V1_ChatServiceClientInterface: Sendable {
    func say(request: Eliza_V1_SayRequest, headers: Headers)
        async -> ResponseMessage<Eliza_V1_SayResponse>
}

public final class Eliza_V1_ChatServiceClient: Eliza_V1_ChatServiceClientInterface, Sendable {
    private let client: ProtocolClientInterface

    public init(client: ProtocolClientInterface) {
        self.client = client
    }

    public func say(request: Eliza_V1_SayRequest, headers: Headers = [:])
        async -> ResponseMessage<Eliza_V1_SayResponse>
    {
        return await self.client.unary(path: "connectrpc.eliza.v1.ElizaService/Say", request: request, headers: headers)
    }
}
```

</details>

This code can then be integrated with just a few lines:

```swift
final class MessagingViewModel: ObservableObject {
    private let elizaClient: Eliza_V1_ChatServiceClientInterface

    init(elizaClient: Eliza_V1_ChatServiceClientInterface) {
        self.elizaClient = elizaClient
    }

    @Published private(set) var messages: [Message] {...}

    func send(_ userSentence: String) async {
        let request = Eliza_V1_SayRequest.with { $0.sentence = userSentence }
        let response = await self.elizaClient.say(request: request, headers: [:])
        if let elizaSentence = response.message?.sentence {
            self.messages.append(Message(sentence: userSentence, author: .user))
            self.messages.append(Message(sentence: elizaSentence, author: .eliza))
        }
    }
}
```

That’s it! You no longer need to manually define Swift response models,
add `Codable` conformances, type out `URL(string: ...)` initializers,
or even create protocol interfaces to wrap service classes - all this is taken
care of by Connect-Swift, and the underlying network transport is
handled automatically.

Testing also becomes a breeze with generated mocks which conform to the same
protocol interfaces as the production clients:

<details><summary>Click to expand <code>eliza.mock.swift</code></summary>

```swift
open class Eliza_V1_ChatServiceClientMock: Eliza_V1_ChatServiceClientInterface, @unchecked Sendable {
    public var mockAsyncSay = { (_: Eliza_V1_SayRequest) -> ResponseMessage<Eliza_V1_Response> in .init(message: .init()) }

    open func say(request: Eliza_V1_SayRequest, headers: Headers = [:])
        async -> ResponseMessage<Eliza_V1_SayResponse>
    {
        return self.mockAsyncSay(request)
    }
}
```

</details>

```swift
func testMessagingViewModel() async {
    let client = Eliza_V1_ChatServiceClientMock()
    client.mockAsyncSay = { request in
        XCTAssertEqual(request.sentence, "hello!")
        return ResponseMessage(result: .success(.with { $0.sentence = "hi, i'm eliza!" }))
    }

    let viewModel = MessagingViewModel(elizaClient: client)
    await viewModel.send("hello!")

    XCTAssertEqual(viewModel.messages.count, 2)
    XCTAssertEqual(viewModel.messages[0].message, "hello!")
    XCTAssertEqual(viewModel.messages[0].author, .user)
    XCTAssertEqual(viewModel.messages[1].message, "hi, i'm eliza!")
    XCTAssertEqual(viewModel.messages[1].author, .eliza)
}
```

## Quick Start

Head over to our [quick start tutorial][getting-started] to get started.
It only takes ~10 minutes to complete
a working SwiftUI chat app that uses Connect-Swift!

## Documentation

Comprehensive documentation for everything, including
[interceptors][interceptors], [mocking/testing][testing],
[streaming][streaming], and [error handling][error-handling]
is available on the [connectrpc.com website][getting-started].

## Example Apps

Example apps are available in the [`Examples`](./Examples)
directory and can be opened and built using Xcode. They demonstrate:

- Using streaming APIs
- Integrating with Swift Package Manager
- Integrating with CocoaPods
- Using the [Connect protocol][connect-protocol]
- Using the [gRPC protocol][grpc-protocol]
- Using the [gRPC-Web protocol][grpc-web-protocol]

## Contributing

We'd love your help making Connect better!

Extensive instructions for building the library and generator plugins locally,
running tests, and contributing to the repository are available in our
[`CONTRIBUTING.md` guide](./.github/CONTRIBUTING.md). Please check it out
for details.

## Ecosystem

- [connect-kotlin][connect-kotlin]: Idiomatic gRPC & Connect RPCs for Kotlin
- [connect-go][connect-go]: Go service stubs for servers
- [connect-es][connect-es]: Type-safe APIs with Protobuf and TypeScript
- [Buf Studio][buf-studio]: Web UI for ad-hoc RPCs
- [conformance][connect-conformance]: Connect, gRPC, and gRPC-Web
  interoperability tests

## Status

This project is in beta, and we may make a few changes as we gather feedback
from early adopters. Join us on [Slack][slack]!

## Legal

Offered under the [Apache 2 license](./LICENSE).

[blog]: https://buf.build/blog/announcing-connect-swift
[buf-studio]: https://buf.build/studio
[connect-conformance]: https://github.com/connectrpc/conformance
[connect-go]: https://github.com/connectrpc/connect-go
[connect-kotlin]: https://github.com/connectrpc/connect-kotlin
[connect-protocol]: https://connectrpc.com/docs/protocol
[connect-es]: https://github.com/connectrpc/connect-es
[error-handling]: https://connectrpc.com/docs/swift/errors
[getting-started]: https://connectrpc.com/docs/swift/getting-started
[grpc-protocol]: https://github.com/grpc/grpc/blob/master/doc/PROTOCOL-HTTP2.md
[grpc-web-protocol]: https://github.com/grpc/grpc/blob/master/doc/PROTOCOL-WEB.md
[interceptors]: https://connectrpc.com/docs/swift/interceptors
[protobuf]: https://developers.google.com/protocol-buffers
[slack]: https://buf.build/links/slack
[streaming]: https://connectrpc.com/docs/swift/using-clients#using-generated-clients
[swift-pm-integration]: https://connectrpc.com/docs/swift/getting-started#add-the-connect-swift-package
[testing]: https://connectrpc.com/docs/swift/testing
