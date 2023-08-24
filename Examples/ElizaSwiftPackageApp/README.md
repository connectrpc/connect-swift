# ElizaSwiftPackageApp example

This example app imports the `Connect` library using Swift Package Manager,
and provides an interface for
[chatting with Eliza](https://buf.build/connectrpc/eliza).

The app has support for chatting using a variety of protocols supported by
the Connect library:

- [Connect](https://connectrpc.com) + unary
- [Connect](https://connectrpc.com) + streaming
- [gRPC](https://github.com/grpc/grpc/blob/master/doc/PROTOCOL-HTTP2.md) + unary (using `ConnectGRPC` + `SwiftNIO`)
- [gRPC](https://github.com/grpc/grpc/blob/master/doc/PROTOCOL-HTTP2.md) + streaming (using `ConnectGRPC` + `SwiftNIO`)
- [gRPC-Web](https://github.com/grpc/grpc/blob/master/doc/PROTOCOL-WEB.md) + unary
- [gRPC-Web](https://github.com/grpc/grpc/blob/master/doc/PROTOCOL-WEB.md) + streaming

## Try it out

Simply open the `.xcodeproj` in this directory and build the app target
using Xcode.

Note that the project uses a local reference to the Connect package,
rather than the GitHub URL.
