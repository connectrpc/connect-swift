# Migrating to Connect-Swift 2.0

This guide describes what changed between Connect-Swift 1.x and 2.0 and how to update an app
or library that uses it. Each section covers one change: what is different, and what, if
anything, you need to do.

## Toolchain

Swift 6.2 / Xcode 26 or later is required. Deployment targets are unchanged.

## Callback API

The callback API is still available, and its signatures are unchanged, so code that calls it
compiles as before. Each callback method is now a thin layer over the matching async method. A
unary call starts a Swift Concurrency task, awaits the async `unary` on it, and passes the
response to your completion handler. A stream call opens the stream through the async API and
starts a task that passes each result to your `onResult` closure. That brings some improvements,
and a few changes worth checking your code for.

### Improvements

- **Your closures no longer run on the transport's queue.** Completion handlers and `onResult`
  closures used to run on `URLSessionHTTPClient`'s serial delegate queue or on a SwiftNIO event
  loop, so a slow closure held up every other request on the same client. They now run on a
  task, and the transport keeps working while they do.
- **A completion handler is always called after the call that started it has returned.**
  Before, a request that failed before it was sent, for example because its message could not
  be serialized, could call its completion handler synchronously, before the call returned.
- **With `NIOHTTPClient` and a timeout, a unary call's completion handler is called once.**
  Before, the timeout could occasionally fire after the response and call it a second time,
  with `.deadlineExceeded`.
- **A type that implements `ProtocolClientInterface` itself no longer has to implement the four
  callback methods.** Default implementations call its four async methods.

### What to check in your code

- **Closures are called from a Swift Concurrency task, not from the transport's queue.**
  Neither queue was the main thread, so code that updates the UI already had to hop to the main
  actor, and still does. Code that checks it is on the old queue, for example with
  `dispatchPrecondition` or `EventLoop.inEventLoop`, must stop doing so.
- **Closures for different calls on the same client can run at the same time.**
  `URLSessionHTTPClient` used to call them one at a time, so state they shared was safe without
  a lock. Protect that state yourself. In Swift 6 language mode the compiler checks this,
  because the closures are `@Sendable`; in Swift 5 mode it does not.
- **Separate unary calls have no defined order.** That was always true on the wire, but a
  callback unary call used to reach the transport before the method returned, so back-to-back
  calls usually went out in call order. Now each call starts on its own task, so they may not.
  If a call depends on another's result, make it after the first completes, from its completion
  handler, or by awaiting both in turn with the async API. If later calls replace earlier ones,
  such as repeated saves of a draft, don't rely on order: cancel the earlier call, or send a
  version the server can check.
- **Don't block inside a closure.** A closure that waits on a semaphore or does slow synchronous
  work holds one of the threads Swift Concurrency shares across your app, and there are only
  about as many of those as CPU cores.
- **Check the signatures of callback methods you implement yourself.** If one doesn't exactly
  match the protocol requirement, for example because a closure parameter lacks `@Sendable`,
  the compiler only warns that it nearly matches, and calls through the protocol use the default
  implementation instead of yours.

### What stays the same

- Canceling a unary call's `Cancelable` completes the call with `.canceled`, and calling
  `cancel()` on a stream ends the stream with `.canceled`.
- A stream's `onResult` closure is called in order and never concurrently, ending with one
  `.complete`.
- Messages sent on one stream arrive in the order they were sent.
- Dropping a stream handle doesn't stop the stream: results keep arriving until it completes.
