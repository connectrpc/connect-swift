Connect-Swift
=============

[![Build](https://github.com/bufbuild/connect-swift/actions/workflows/ci.yaml/badge.svg?branch=main)](https://github.com/bufbuild/connect-swift/actions/workflows/ci.yaml)

Connect-Swift is a small library (<200KB!) that provides support for using
generated,
type-safe, and idiomatic Swift APIs to communicate with your app's servers
using [Protocol Buffers (Protobuf)](https://developers.google.com/protocol-buffers).
Imagine a world where
you don't have to handwrite `Codable` models for REST/JSON endpoints
and you can instead get right to building features by calling a generated
API method that is guaranteed to match the server's modeling. Furthermore,
imagine never having to worry about serialization again, and being able to
easily write tests using generated mocks that conform to the same protocol
that the real implementations do. All of this is possible with Connect-Swift.

A further introduction to why you should use Connect-Swift can be found
on our [blog][blog].

# Quick Start Demo (Recommended)

**We highly recommend starting with our
[quick start tutorial][getting-started]. It only takes ~10 minutes to complete
a working SwiftUI chat app that uses Connect-Swift.**

Comprehensive documentation for everything, including
[interceptors][interceptors], [mocking/testing][testing],
[streaming][streaming], and [error handling][error-handling]
is available on the [connect.build website][getting-started].

# Integrate

**The connect.build site contains [extensive-documentation][getting-started]
on how to get started with Connect-Swift. We recommend using that and treating
the instructions below as supplementary.**

## Configure Code Generation

The easiest way to get started using Connect-Swift is to use
[Buf's remote generation](https://docs.buf.build/bsr/remote-plugins/overview):

1. Install Buf's CLI (`brew install bufbuild/buf/buf`).
2. Initialize Buf in your project directory (`buf mod init`).
3. Add a `buf.gen.yaml` file to your project which contains a configuration for running both the [SwiftProtobuf](https://github.com/apple/swift-protobuf) and Connect-Swift plugin generators:

```yaml
version: v1
managed:
  enabled: true
plugins:
  - plugin: buf.build/bufbuild/connect-swift
    opt: >
      GenerateAsyncMethods=true,
      GenerateCallbackMethods=true,
      Visibility=Public
    out: Generated
  - plugin: buf.build/apple/swift
    opt: Visibility=Public
    out: Generated
```

4. Run `make generate` (or `buf generate`), and you should see the outputted files!
5. Now that you have generated models & APIs from your `.proto` files, you'll need to integrate the runtime using one of the methods below.

## Integrate with Swift Package Manager

The easiest way to integrate with connect-swift is to depend on the `Connect`
package specified in [`Package.swift`](./Package.swift), as you would any
other Swift package.

Our getting started guide has a [complete set of steps][swift-pm-integration]
that explain how to do this.

Once you've added the `Connect` dependency (and its transitive dependency
on `SwiftProtobuf`), add the generated `.swift` files from the code generation
step, and your project should build!

For an example of integrating `Connect` via Swift Package Manager,
see the [`ElizaSwiftPackageApp`](./ConnectExamples/ElizaSwiftPackageApp).

## Integrate with CocoaPods

Although Swift Package Manager is the preferred distribution method for
the Connect library, we also provide a [podspec](./Connect-Swift.podspec) for
CocoaPods support.

To integrate using CocoaPods, add this line to your `Podfile`:

```rb
# Use the current version (automatically pinned in Podfile.lock after):
pod 'Connect-Swift'

# Or pin a specific version:
pod 'Connect-Swift', '~> x.y.z'
```

You can then use the library by adding `import Connect` to your sources.

For an example of integrating `Connect` via CocoaPods,
see the [`ElizaCocoaPodsApp`](./ConnectExamples/ElizaCocoaPodsApp).

# Example Apps

We have example apps in this repository that demonstrate:

- Using streaming APIs
- Integrating with Swift Package Manager
- Integrating with CocoaPods
- Using the [Connect protocol][connect-protocol]
- Using the [gRPC-Web protocol][grpc-web-protocol]

Example apps are available in the [`ConnectExamples`](./ConnectExamples)
directory and can be opened and built using Xcode.

# Contributing

We'd love your help making Connect better!

Extensive instructions for building the library and generator locally,
running tests, and contributing to the repository are available in our
[`CONTRIBUTING.md` guide](./.github/CONTRIBUTING.md). Please check it out
for details.

# Legal

Offered under the [Apache 2 license](./LICENSE).

# Ecosystem

- [connect-go][connect-go]: Go service stubs for servers
- [connect-web][connect-web]: TypeScript clients for web browsers
- [Buf Studio][buf-studio]: Web UI for ad-hoc RPCs
- [connect-crosstest][connect-crosstest]: Connect, gRPC, and gRPC-Web interoperability tests

[blog]: https://buf.build/blog/announcing-connect-swift
[buf-studio]: https://studio.buf.build
[connect-crosstest]: https://github.com/bufbuild/connect-crosstest
[connect-go]: https://github.com/bufbuild/connect-go
[connect-protocol]: https://connect.build/docs/protocol
[connect-web]: https://www.npmjs.com/package/@bufbuild/connect-web
[error-handling]: https://connect.build/docs/swift/errors
[getting-started]: https://connect.build/docs/swift/getting-started
[grpc-web-protocol]: https://github.com/grpc/grpc-web
[interceptors]: https://connect.build/docs/swift/interceptors
[streaming]: https://connect.build/docs/swift/using-clients#using-generated-clients
[swift-pm-integration]: https://connect.build/docs/swift/getting-started#add-the-connect-swift-package
[testing]: https://connect.build/docs/swift/testing
