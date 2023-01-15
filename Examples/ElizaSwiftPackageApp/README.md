# ElizaSwiftPackageApp example

This example app imports the `Connect` library using Swift Package Manager,
and provides an interface for
[chatting with Eliza](https://buf.build/bufbuild/eliza).

The app has support for chatting using a variety of protocols supported by
the Connect library:

- [Connect](https://connect.build) + unary
- [Connect](https://connect.build) + streaming
- [gRPC-Web](https://grpc.io) + unary
- [gRPC-Web](https://grpc.io) + streaming

## Try it out

Simply open the `.xcodeproj` in this directory and build the app target
using Xcode.

Note that the project uses a local reference to the Connect package,
rather than the GitHub URL.
