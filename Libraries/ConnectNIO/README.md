## ConnectNIO

This module provides an `NIOHTTPClient` which conforms to the Connect
library's `HTTPClientInterface` protocol and is backed by the
[SwiftNIO](https://github.com/apple/swift-nio) networking stack.

Additionally, since SwiftNIO supports trailers, this module provides support
for using the gRPC protocol alongside the Connect and gRPC-Web protocols
provided by the main Connect library.

This library is unavailable through CocoaPods since
[SwiftNIO does not support CocoaPods](https://github.com/apple/swift-nio/issues/2393),
and it can only be consumed using Swift Package Manager.
