# Migrating to Connect-Swift 2.0

This guide describes what changed between Connect-Swift 1.x and 2.0 and how to update an app
or library that uses it. Each section covers one change: what is different, and what, if
anything, you need to do.

## Toolchain

Swift 6.2 / Xcode 26 or later is required. Deployment targets are unchanged.

## Callback API

The callback API is still available, and its signatures are unchanged. It is now built on the
async API, which changes three things a caller can observe:

- Completion handlers and `onResult` closures are called from a Swift Concurrency task, not
  from the transport's queue (URLSession's delegate queue or a SwiftNIO event loop). Code that
  relied on that queue must hop to it itself.
- A call returns before its request has started; the request starts on that task. Two unary
  calls made back to back are no longer guaranteed to be sent in that order. Messages sent on
  one stream still arrive in the order they were sent.
- A type that implements `ProtocolClientInterface` itself no longer has to implement the four
  callback methods.
