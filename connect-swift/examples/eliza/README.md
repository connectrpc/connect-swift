# Eliza example

This example app imports the `Connect` library using Swift Package Manager,
and provides an interface for
[chatting with Eliza](https://buf.build/bufbuild/eliza).

The app has support for chatting using a variety of protocols supported by
the Connect library:

- [Connect](https://connect.build) + unary
- [Connect](https://connect.build) + streaming
- [gRPC](https://grpc.io) + unary
- [gRPC](https://grpc.io) + streaming

To try out the app, simply open the `.xcodeproj` in this directory.
