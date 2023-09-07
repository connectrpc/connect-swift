# ElizaSwiftPackageApp example

This example app imports the `Connect` library using CocoaPods,
and provides an interface for
[chatting with Eliza](https://connectrpc.com/demo).

The app has support for chatting using a variety of protocols supported by
the Connect library:

- [Connect](https://connectrpc.com) + unary
- [Connect](https://connectrpc.com) + streaming
- [gRPC-Web](https://github.com/grpc/grpc/blob/master/doc/PROTOCOL-WEB.md) + unary
- [gRPC-Web](https://github.com/grpc/grpc/blob/master/doc/PROTOCOL-WEB.md) + streaming

**Note that vanilla gRPC support is not available in this example because
[SwiftNIO does not support CocoaPods](https://github.com/apple/swift-nio/issues/2393).**

## Try it out

1. Ensure you have CocoaPods installed (`brew install cocoapods`)
2. `cd` into this directory and install the pods (`pod install`)
3. Open the generated `.xcworkspace` file (`xed .`)
4. Build the app target using Xcode

Note that the [`Podfile`](./Podfile) uses a local path reference to the
Connect library in this repository, rather than the one in the CocoaPods
specs repo.
