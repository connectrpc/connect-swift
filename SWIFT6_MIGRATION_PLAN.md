# Swift 6 / Strict-Concurrency Migration Plan for connect-swift

**Status:** Plan (not yet implemented) · **Branch:** `eddie/swift6` · **Written:** 2026-07-19
**Toolchains verified against:** local Xcode 26.6 (Swift 6.3.3); CI pins Xcode 26.4.1 (`DEVELOPER_DIR` in `.github/workflows/ci.yml`).

This plan is written for a mechanical implementor: every isolation-design decision,
API-compatibility tradeoff, and ordering question is resolved *here*. If a step's
verification fails in a way this plan does not anticipate, stop and report — do not
invent a new isolation design.

Analytical lens: the `/swift-concurrency` skill. Where its guidance shaped a decision,
it is cited inline as **[skill: …]**.

---

## 0. Verified ground truth (re-derived from the repo on 2026-07-19)

Per **[skill: Fast Path — "Analyze Package.swift … to determine Swift language mode,
strict concurrency level … Do this always"]**, the settings were verified empirically,
not assumed. The single most important finding:

> **The package already compiles in Swift 6 language mode on any Swift 6 toolchain.**
> `swift build -v` on the current `main`/`eddie/swift6` HEAD passes `-swift-version 6`
> to every target of this package and exits 0, with exactly **four warnings**, all in
> `Libraries/ConnectNIO/Public/NIOHTTPClient.swift` (lines 85, 91, 238), downgraded
> from errors by the `@preconcurrency` imports of `NIOCore`/`NIOSSL`.

This reframes the migration: it is **not** "turn on Swift 6 mode" (that happened in
commit `75e74ea`, "Use Swift 6 when available", via `swiftLanguageVersions`). It is:

1. modernize the manifest so the Swift 6 contract is explicit and tooling-visible,
2. drive the remaining 4 warnings to zero,
3. triage every `@unchecked Sendable` (keep-with-justification vs. genuinely remove),
4. reconcile the CocoaPods / generated-code / example-app distribution surfaces,
5. land the known concurrency-adjacent crash fix that Swift 6 *cannot* catch.

### 0.1 Manifest semantics (what the current combination does and does not do)

`Package.swift` currently has `// swift-tools-version:5.6` at the top and
`swiftLanguageVersions: [.version("6"), .v5]` at the bottom.

- `swift-tools-version:5.6` sets the **manifest API level** and the minimum SwiftPM
  that can *parse* the manifest. It does **not** by itself pick the language mode of
  the targets (the tools-version default would be Swift 5 mode).
- `swiftLanguageVersions` declares the language modes the package supports; SwiftPM
  compiles all targets with **the newest listed mode the toolchain supports**. On a
  Swift 6.x toolchain that is `6` → Swift 6 language mode → data-race safety enforced
  as **errors** (equivalent to `-strict-concurrency=complete` plus error promotion).
  On a Swift 5.x toolchain it falls back to `.v5` (minimal checking). Verified: the
  build log shows `-swift-version 6` for package targets (the lone `-swift-version 5`
  entry is the compilation of `Package.swift` itself, at
  `-package-description-version 5.6.0`).
- What tools-version 5.6 does **not** allow in the manifest:
  - `.enableUpcomingFeature` / `.enableExperimentalFeature` — need tools **5.8+**
  - `package` access level — needs tools **5.9+**
  - `SwiftSetting.swiftLanguageMode(_:)` per target, and the renamed
    `swiftLanguageModes:` package parameter — need tools **6.0+**
  - `.defaultIsolation(MainActor.self)` — needs tools **6.2+** (not wanted here; see §3.4)

**Required bump: `// swift-tools-version:6.0`.** Not 6.2 — we use no 6.2-only manifest
API, and 6.0 maximizes the range of consumer toolchains that can parse the manifest.

**Cost of the bump to consumers: none in practice.** swift-nio 2.92.2 (a declared
dependency) ships a *single* manifest that is itself `// swift-tools-version:6.0`
(verified in `.build/checkouts/swift-nio/Package.swift`). SwiftPM parses every manifest
in the dependency graph regardless of which product is consumed, so every SwiftPM
consumer of connect-swift **already** needs a Swift 6.0+ toolchain (Xcode 16+).
CocoaPods consumers never read `Package.swift` (the podspecs list `source_files`
directly), so the bump is invisible to them.

### 0.2 Target inventory (from `Package.swift`)

| Target | Kind | Path | Concurrency-relevant notes |
|---|---|---|---|
| `Connect` | library | `Libraries/Connect` | Core; iOS 12/macOS 10.15/tvOS 13/watchOS 6 floor; async APIs gated `@available(iOS 13, *)` |
| `ConnectMocks` | library | `Libraries/ConnectMocks` | 6 `open class` mocks, all `@unchecked Sendable`, documented non-thread-safe |
| `ConnectNIO` | library | `Libraries/ConnectNIO` | `@preconcurrency import NIOCore/NIOSSL`; owns `MultiThreadedEventLoopGroup(numberOfThreads: 1)`; all 4 remaining warnings |
| `ConnectSwiftPlugin` | executable | `Plugins/ConnectSwiftPlugin` | codegen; its *output* compiles in consumers' modules |
| `ConnectMocksPlugin` | executable | `Plugins/ConnectMocksPlugin` | codegen; emits `@unchecked Sendable` mock classes |
| `ConnectPluginUtilities` | library | `Plugins/ConnectPluginUtilities` | single-threaded codegen support; already clean in v6 mode |
| `ConnectConformanceClient` | executable | `Tests/ConformanceClient` | driven by `make testconformance` |
| `ConnectLibraryTests`, `ConnectPluginUtilitiesTests` | test | `Tests/UnitTests/…` | Swift Testing (`import Testing`) already |

### 0.3 Complete `@unchecked Sendable` inventory (Libraries/Plugins; verdicts in §4)

| # | Site | Verdict (§4) |
|---|---|---|
| 1 | `Libraries/Connect/Internal/Utilities/Lock.swift:18` `Lock` | Keep + comment |
| 2 | `Libraries/Connect/Internal/Utilities/Locked.swift:19` `Locked<Wrapped>` | Keep + comment |
| 3 | `Libraries/Connect/Internal/Utilities/TimeoutTimer.swift:17` `TimeoutTimer` | **Remove** (restructure to checked `Sendable`) |
| 4 | `Libraries/Connect/Internal/Streaming/URLSessionStream.swift:21` | Keep + expand comment |
| 5 | `Libraries/Connect/Internal/Streaming/BidirectionalAsyncStream.swift:26` | Keep, but shrink unsafe surface (`Locked` for `requestCallbacks`) + comment |
| 6 | `Libraries/Connect/Internal/Streaming/ClientOnlyAsyncStream.swift:26` | Keep (inherits #5) + comment |
| 7 | `Libraries/Connect/Internal/Streaming/ClientOnlyStream.swift:21` | **Remove** (restructure to checked `Sendable`) |
| 8 | `Libraries/Connect/Public/Implementation/Clients/ProtocolClient.swift:443` `PendingRequestCallbacks` | **Remove** (restructure to checked `Sendable`) |
| 9 | `Libraries/Connect/Public/Implementation/Clients/URLSessionHTTPClient.swift:23` | Keep (public API; open class) — justification exists, tighten |
| 10 | `URLSessionHTTPClient.swift:198` `URLSessionDelegateWrapper` | Keep + comment (`weak var` cannot be `let`) |
| 11–16 | `Libraries/ConnectMocks/Mock*.swift` (6 classes) | Keep + comment (deliberately non-thread-safe test doubles; `open`) |
| 17 | `Libraries/ConnectNIO/Internal/ConnectStreamChannelHandler.swift:22` | Keep + event-loop-confinement comment |
| 18 | `Libraries/ConnectNIO/Internal/ConnectUnaryChannelHandler.swift:22` | Keep + event-loop-confinement comment |
| 19 | `Libraries/ConnectNIO/Internal/GRPCInterceptor.swift:283` private `Locked<T>` | Keep + comment |
| 20 | `Libraries/ConnectNIO/Public/NIOHTTPClient.swift:26` | Keep (public API; open class) + comment |

Additional sites outside the shipping libraries:
- `Tests/UnitTests/ConnectLibraryTests/ConnectTests/TimeoutTests.swift:63`
  (`TimeoutHTTPClient` test double) — keep, add a one-line justification comment.
- `Tests/…/GeneratedSources/**/client_compat.pb.swift` — emitted by **swift-protobuf's**
  generator (heap-storage message), not by our plugins. Out of scope; do not edit
  generated files by hand.
- `Plugins/ConnectMocksPlugin/ConnectMockGenerator.swift:66–71` — the *template* that
  emits `@unchecked Sendable` on generated mocks. It already emits the justification
  comment ("does not handle thread-safe locking, but provides `@unchecked Sendable`
  conformance to simplify testing and mocking"). Keep as-is (§8).

### 0.4 Other verified facts

- `InterceptorChain` (`Libraries/Connect/Internal/Interceptors/InterceptorChain.swift`)
  is already **checked** `Sendable` (immutable `let interceptors: [T]`, all closures
  `@Sendable`). No changes needed; risk discussion in §9.
- `RequestCallbacks<T>`, `ResponseCallbacks`, `Cancelable`, `HTTPRequest`,
  `HTTPResponse`, `HTTPMetrics`, `HTTPClientInterface`, `ProtocolClient` are all
  already checked-`Sendable` public types.
- `UnaryAsyncWrapper` is already a proper `actor`; no changes needed.
- Unit tests already use **Swift Testing**, not XCTest.
- `Examples/ElizaSwiftPackageApp` already builds with `SWIFT_VERSION = 6.0`
  (verified in its `project.pbxproj`) — the SwiftPM example is *already* a
  Swift-6-mode consumer of the generated code, and it is green in CI.
- Podspecs (`Connect-Swift.podspec`, `Connect-Swift-Mocks.podspec`) pin
  `spec.swift_versions = ['5.0']` → CocoaPods consumers compile the library sources
  in **Swift 5 mode** today. The `ElizaCocoaPodsApp` CI job is therefore the
  regression gate proving the sources remain valid Swift-5-mode code.
- Unmerged fix on local branch `eddie/conformance-test-flakiness`, commit `6367acb`
  ("Fix crash when NIOHTTPClient is deallocated on its own event loop"): replaces
  `try? self.loopGroup.syncShutdownGracefully()` in `NIOHTTPClient.deinit` with
  `self.loopGroup.shutdownGracefully { _ in }` plus an explanatory comment. §2 makes
  this Phase 0.
- Timing-bug precedent: `d9eda55` ("Fix deadlock on request timeout") — `TimeoutTimer.cancel()`
  used to deadlock when called from within its own fired work item. Informs §4.3.

---

## 1. Phase overview and ordering rationale

Per **[skill: Six Migration Habits — iterate in small chunks; resist the urge to
refactor; smallest safe change]**, each phase compiles and passes the full gate suite
(§10) on its own and is a mergeable checkpoint. Ordering:

| Phase | Content | Why this order |
|---|---|---|
| 0 | Land `6367acb` (NIO deinit crash fix); record warning baseline | A known crash makes conformance CI untrustworthy; migration needs a clean signal. Also: Swift 6 will *never* flag this bug (§9.1) — waiting for the migration to "catch it" would wait forever. |
| 1 | Manifest modernization (tools 6.0, `swiftLanguageModes`) | Unblocks per-target `SwiftSetting` if ever needed; zero behavior change, easy revert point. |
| 2 | `Connect` target: remove 3 `@unchecked Sendable`s, shrink 2, comment the rest | Core target first — fewest external dependencies, no `@preconcurrency` involved **[skill: Step-by-Step — start with the most isolated code]**. |
| 3 | `ConnectNIO`: eliminate the 4 warnings; justify/date `@preconcurrency`; comment handlers | Depends on nothing in Phase 2, but done after so Connect-level primitives (`Locked` comments etc.) are settled vocabulary. NIO's heavier unchecked usage stays, with confinement documented. |
| 4 | Plugins + generated code + mocks + tests: comments, regeneration, consumer-mode verification | Templates verified against a real Swift-6-mode consumer (Eliza SwiftPM app). |
| 5 | Distribution: podspecs `swift_versions`, README notes | Only after the sources are warning-free in v6 mode. |
| 6 | CI acceptance: zero-warning enforcement job | Locks in the end state. |

A note on the original expectation of "enable Swift 6 on `Connect` before
`ConnectNIO`": that staging is **moot** — both targets already compile in Swift 6
mode (§0). The per-target staging in this plan is therefore about *escape-hatch
removal*, not language-mode enablement. Do not add per-target
`.swiftLanguageMode(.v5)` anywhere; that would be a regression.

---

## 2. Phase 0 — Land the NIOHTTPClient deinit fix; baseline

### Why first, and what it teaches about isolation design

The bug: an `EventLoopFuture` callback in `connectChannelAndMultiplexerIfNeeded()`
captures `[weak self]`; when it briefly upgrades to a strong reference and every
other owner has released the client, dropping that reference runs `deinit` **on the
client's own NIO event-loop thread**. `deinit` called `syncShutdownGracefully()`,
which has a precondition that traps when called from an event loop → silent SIGTRAP.
In the conformance suite the client processes stdin cases serially, so one crash made
every queued case time out at once (the CI flake burst).

Case-study takeaways baked into this plan's isolation design:

- **Swift 6 strict concurrency does not check `deinit` isolation.** `deinit` is
  nonisolated and runs on whatever thread drops the last reference. A class can be
  100% warning-free under `-strict-concurrency=complete` and still have exactly this
  bug. (SE-0371 `isolated deinit` exists in newer runtimes but is unusable at this
  package's iOS 12 floor.) Consequence: every `deinit` in classes we keep as
  `@unchecked Sendable` must be audited for thread assumptions *manually* — this
  plan does so: `NIOHTTPClient.deinit` (fixed here), `URLSessionHTTPClient.deinit`
  (`finishTasksAndInvalidate()` is documented thread-safe — OK), `TimeoutTimer.deinit`
  (`cancel()` → `DispatchWorkItem.cancel()` is thread-safe — OK), `Lock.deinit`
  (pointer teardown, single-owner — OK).
- The fix (async `shutdownGracefully { _ in }`) is the right one; do **not** attempt
  to "actorize" `NIOHTTPClient` instead (§4.7).

### Steps

1. From `eddie/swift6`, cherry-pick the fix commit:
   ```bash
   git cherry-pick 6367acb
   ```
   Only `Libraries/ConnectNIO/Public/NIOHTTPClient.swift` should change (the other
   commits on `eddie/conformance-test-flakiness` — stderr logging, swiftlint style —
   are unrelated to this migration; leave them to their own PR).
2. Verify the diff matches: `deinit` now ends with
   `self.loopGroup.shutdownGracefully { _ in }` and the multi-line comment explaining
   the event-loop-deinit hazard.
3. Run the full gate suite (§10.1) and record the baseline warning count:
   ```bash
   swift build 2>&1 | grep "warning:" | grep -v swift-frontend | sort -u
   ```
   Expected: exactly the 4 `NIOHTTPClient.swift` warnings listed in §5.1. If more
   appear (e.g., newer Xcode than 26.4.1 surfacing new diagnostics), record them and
   fold them into Phase 3's worklist.

**Done when:** cherry-pick applied cleanly; `make testconformance` passes both
`urlsession` and `nio` configs; baseline = 4 warnings, all in `NIOHTTPClient.swift`.

---

## 3. Phase 1 — Manifest modernization

### 3.1 Edits to `Package.swift`

1. Line 1: `// swift-tools-version:5.6` → `// swift-tools-version:6.0`
2. Last line: `swiftLanguageVersions: [.version("6"), .v5]` →
   `swiftLanguageModes: [.v6, .v5]`
   (`swiftLanguageVersions` is the deprecated spelling under tools 6.0;
   `.version("6")` becomes the typed `.v6`.)
3. **No per-target `swiftSettings` are added.** Rationale, spelled out so the
   implementor does not "helpfully" add them:
   - Language mode: the package-level `swiftLanguageModes` already selects v6 on
     every capable toolchain (verified, §0.1); per-target `.swiftLanguageMode(.v6)`
     would be redundant, and `.swiftLanguageMode(.v5)` anywhere would be a regression.
   - `.enableExperimentalFeature("StrictConcurrency")`: meaningless — subsumed by
     Swift 6 mode, which is already active.
   - `.enableUpcomingFeature("ExistentialAny")`: **deliberately out of scope.**
     It is a style-hardening feature that is *not* part of Swift 6 mode, would touch
     dozens of files with no data-race-safety benefit, and violates
     **[skill: Resist the Urge to Refactor — focus solely on concurrency changes]**.
   - `.defaultIsolation(MainActor.self)`: wrong for a library. **[skill: Don't Just
     @MainActor All the Things — the MainActor-default recommendation is for app
     targets, not frameworks]**. This package's code is transport-layer and must run
     off the main actor; the correct default isolation is `nonisolated`, which is
     what it already has.

### 3.2 Why keeping `.v5` in `swiftLanguageModes` matters

CocoaPods consumers compile these same sources with `SWIFT_VERSION = 5.0` (podspec,
§7). `swiftLanguageModes: [.v6, .v5]` is the manifest-level documentation of that
dual-mode contract; every capable SwiftPM toolchain still picks `.v6`. The
`ElizaCocoaPodsApp` CI job remains the executable proof that the sources stay valid
in Swift 5 mode. Do not drop `.v5` until the podspecs drop `'5.0'` (a future,
separate decision).

### 3.3 Interaction warning (for the implementor)

After the tools bump, the *manifest itself* compiles in Swift 6 mode. If SwiftPM
emits new warnings about the manifest, fix them in `Package.swift` only. Do not
touch target sources in this phase.

### 3.4 Verification

```bash
swift build -v 2>&1 | grep -o '\-swift\-version [0-9]*' | sort | uniq -c
```
Expected: every target compilation shows `-swift-version 6`; the manifest line now
shows `-package-description-version 6.0.0`. Then the full gate suite (§10.1) and both
example apps (§10.2). Warning count must still be exactly the Phase 0 baseline (4).

---

## 4. Phase 2 — `Connect` target: escape-hatch triage

General policy, per **[skill: guardrail — "If recommending `@preconcurrency`,
`@unchecked Sendable`, or `nonisolated(unsafe)`, require a documented safety
invariant and a follow-up removal plan"]**: every *kept* `@unchecked Sendable` gets
an inline comment stating (a) why checked conformance is impossible, (b) the
invariant that makes it safe, (c) what future change would allow removal. Every
*removable* one is removed by restructuring, not by wallpapering.

Also per **[skill: Migration Validation Loop]**: apply the subsections below **one
file at a time**, running `swift build` after each file and `make testunit` after
each subsection, before moving to the next. Do not batch.

### 4.1 `Lock.swift` — keep, comment (no code change)

`Lock` *is* the synchronization primitive; its unsafety (`UnsafeMutablePointer<os_unfair_lock>`)
is inherent and cannot be expressed as checked `Sendable`. Replace nothing.

Edit: extend the class doc comment:

```swift
/// Internal implementation of a lock. Wraps usage of `os_unfair_lock`.
///
/// Safety: `@unchecked Sendable` because this type *is* the synchronization
/// primitive — the pointer is allocated once in `init`, only ever accessed via
/// `os_unfair_lock_lock`/`unlock`, and deallocated in `deinit` when no other
/// thread can still hold a reference.
/// Removal plan: replace with `OSAllocatedUnfairLock` (requires iOS 16/macOS 13
/// minimum) or `Synchronization.Mutex` (iOS 18/macOS 15) if/when deployment
/// targets are raised. See §6 of SWIFT6_MIGRATION_PLAN.md.
final class Lock: @unchecked Sendable {
```

Also fix the stale TODO on line 23: it says "When iOS 15 support is dropped,
`OSAllocatedUnfairLock` should be used" — `OSAllocatedUnfairLock` actually requires
**iOS 16**/macOS 13. Correct the version in the comment.

### 4.2 `Locked.swift` — keep, comment (no code change)

Checked conformance is impossible (`private var wrappedValue: Wrapped` is mutable by
design). Extend the doc comment with the invariant: *all* reads/writes of
`wrappedValue` go through `self.lock.perform`, and callers must not store values
whose thread-safety depends on external state. Removal plan comment: becomes
`Mutex<Wrapped>` when the floor reaches iOS 18/macOS 15.

### 4.3 `TimeoutTimer.swift` — **remove `@unchecked Sendable`** (restructure)

Current hazards: `private var onTimeout` mutated under `queue.sync` (a second,
different serialization mechanism than `Locked`, and `queue.sync` is exactly the
shape that produced the `d9eda55` deadlock), and `private var workItem: DispatchWorkItem!`
is a mutable force-unwrapped stored property that blocks checked conformance.

Replace the whole stored-state layout so every stored property is an immutable
`let` of a `Sendable` type, which makes checked `Sendable` valid **[skill: Smallest
Safe Fixes — prefer immutable values and explicit boundaries over @unchecked
Sendable]**:

```swift
final class TimeoutTimer: Sendable {
    private let hasTimedOut: Locked<Bool>
    private let onTimeout: Locked<(@Sendable () -> Void)?>
    private let queue = DispatchQueue(label: "connectrpc.Timeout")
    private let timeout: TimeInterval
    private let workItem: DispatchWorkItem

    var timedOut: Bool {
        return self.hasTimedOut.value
    }

    init?(config: ProtocolClientConfig) {
        guard let timeout = config.timeout else {
            return nil
        }

        // Locals are created first and captured by the work item so that it does
        // not retain `self` (preserving the previous `[weak self]` lifetime
        // semantics: the timer stops mattering once the last owner cancels it
        // in `deinit`).
        let hasTimedOut = Locked(false)
        let onTimeout = Locked<(@Sendable () -> Void)?>(nil)
        self.timeout = timeout
        self.hasTimedOut = hasTimedOut
        self.onTimeout = onTimeout
        self.workItem = DispatchWorkItem {
            hasTimedOut.value = true
            onTimeout.value?()
        }
    }

    deinit {
        self.cancel()
    }

    func start(onTimeout: @escaping @Sendable () -> Void) {
        let milliseconds = Int(self.timeout * 1_000)
        self.onTimeout.value = onTimeout
        self.queue.asyncAfter(
            deadline: .now() + .milliseconds(milliseconds), execute: self.workItem
        )
    }

    func cancel() {
        self.workItem.cancel()
    }
}
```

Notes for the implementor:
- The `queue.sync { self.onTimeout = onTimeout }` call is deleted entirely — the
  `Locked` wrapper is now the only serialization for that state. This removes the
  lock-ordering interaction between `queue` and callers (`d9eda55` precedent).
- Behavior preserved: timeout still fires on the `connectrpc.Timeout` queue;
  `cancel()` is still safe from any thread including from within the fired work
  item (`DispatchWorkItem.cancel()` does not block).
- Call-site check: `ProtocolClient.swift` passes non-`@Sendable`-annotated closures
  to `start(onTimeout:)` at lines ~400 (`{ pendingRequestCallbacks.enqueue { $0.cancel() } }`);
  these closures only capture `Sendable` values, so adding `@Sendable` to the
  parameter compiles without call-site edits. If the compiler disagrees, fix the
  call site by capturing explicitly, not by removing `@Sendable`.

Verify after this file: `swift build` (0 new warnings), then
`Tests/UnitTests/ConnectLibraryTests/ConnectTests/TimeoutTests.swift` via
`swift test --filter TimeoutTests` if quick iteration is wanted, then full
`make testunit` at the end of the phase.

### 4.4 `ClientOnlyStream.swift` — **remove `@unchecked Sendable`** (restructure)

The only impediment is `private var requestCallbacks: RequestCallbacks<Input>?`
(mutable, set once via `configureForSending`). `RequestCallbacks` is already checked-
`Sendable`. Change:

```swift
final class ClientOnlyStream<Input: ProtobufMessage, Output: ProtobufMessage>: Sendable {
    private let onResult: @Sendable (StreamResult<Output>) -> Void
    private let receivedResults = Locked([StreamResult<Output>]())
    /// Callbacks used to send outbound data and close the stream.
    /// Wrapped because these callbacks are not available until the stream is
    /// initialized (`configureForSending` is called immediately after `init`,
    /// before the stream escapes to the caller).
    private let requestCallbacks = Locked<RequestCallbacks<Input>?>(nil)
```

- `configureForSending(with:)` body becomes `self.requestCallbacks.value = requestCallbacks`.
- `send(_:)` reads `guard let sendData = self.requestCallbacks.value?.sendData`.
- `closeAndReceive()` / `cancel()` read `self.requestCallbacks.value?...`.

Two-phase init is inherent (the callbacks close over the stream instance in
`ProtocolClient.clientOnlyStream`), so constructor injection is not possible; the
`Locked` wrapper is the correct minimal fix, and afterward every stored property is
a `Sendable` `let` → declare checked `Sendable`.

### 4.5 `BidirectionalAsyncStream.swift` (+ `ClientOnlyAsyncStream.swift`) — keep `@unchecked`, shrink and document

`BidirectionalAsyncStream` cannot become checked `Sendable`: `asyncStream` and
`receiveResult` are mutable force-unwrapped vars that are assigned *inside* the
`AsyncStream { continuation in … }` init closure during `init`. That set-once-in-init
pattern is safe but not expressible to the checker without a larger rewrite of the
callback-bridging design — which is explicitly out of scope
**[skill: Resist the Urge to Refactor]** (the class's own doc comment notes it can be
simplified if callback support is ever dropped; that is the removal plan).

Do:
1. Change `private var requestCallbacks: RequestCallbacks<Input>?` to
   `private let requestCallbacks = Locked<RequestCallbacks<Input>?>(nil)` and update
   its four accesses (`configureForSending`, `send`, `close`, `cancel`, and the
   `continuation.onTermination` closure) to `.value` — same mechanics as §4.4. This
   removes the one *genuinely* racy member (it is written by `configureForSending`
   on the caller's thread and read by `onTermination` on arbitrary threads).
2. Add the justification comment above the class:

```swift
/// Safety: `@unchecked Sendable` because `asyncStream` and `receiveResult` are
/// force-unwrapped vars assigned exactly once, synchronously, during `init`
/// (inside the `AsyncStream` bootstrap closure) and never mutated afterward.
/// All post-init mutable state lives in `Locked` wrappers.
/// Removal plan: collapses to a checked-Sendable design if/when the
/// callback-based API surface is removed and this bridge becomes unnecessary.
```

3. `ClientOnlyAsyncStream` needs no code change (its own state, `receivedResults`,
   is already a `let Locked`). Its restated `@unchecked Sendable` is inherited-
   conformance restatement; leave it (removing it changes nothing) and add a
   one-line comment: `// Inherits @unchecked Sendable from BidirectionalAsyncStream; own state is Locked.`

### 4.6 `ProtocolClient.swift` — `PendingRequestCallbacks`: **remove `@unchecked Sendable`**

Restructure the private class so its only stored property is a `Locked` state box:

```swift
private final class PendingRequestCallbacks: Sendable {
    private struct State {
        var callbacks: RequestCallbacks<Data>?
        var queue = [@Sendable (RequestCallbacks<Data>) -> Void]()
    }

    private let state = Locked(State())

    func setCallbacks(_ callbacks: RequestCallbacks<Data>) {
        let pendingActions = self.state.perform { state -> [@Sendable (RequestCallbacks<Data>) -> Void] in
            state.callbacks = callbacks
            let queued = state.queue
            state.queue = []
            return queued
        }
        for action in pendingActions {
            action(callbacks)
        }
    }

    func enqueue(_ action: @escaping @Sendable (RequestCallbacks<Data>) -> Void) {
        let callbacksToCall = self.state.perform { state -> RequestCallbacks<Data>? in
            if let callbacks = state.callbacks {
                return callbacks
            }
            state.queue.append(action)
            return nil
        }
        if let callbacks = callbacksToCall {
            action(callbacks)
        }
    }
}
```

Behavior is identical (actions still run *outside* the lock — preserve that; running
them inside would recreate a `d9eda55`-shaped lock-ordering hazard). The `@Sendable`
added to `enqueue`'s parameter type-checks at all three existing call sites in
`createRequestCallbacks` (they capture only `Sendable` values).

### 4.7 `URLSessionHTTPClient.swift` — keep `@unchecked Sendable`; comment only

Decision, with reasoning the implementor must not relitigate:

- **Checked `Sendable` is impossible while the class stays `open`**: Swift only
  permits checked `Sendable` on `final` classes. The class is explicitly documented
  as subclassable public API; making it `final` is a source-breaking change we are
  not taking in a minor release (§6, §7).
- **Actor conversion is rejected**, not deferred: `HTTPClientInterface` requires
  *synchronous* `unary(...) -> Cancelable` and `stream(...) -> RequestCallbacks`.
  An actor's members are async; conforming would need `nonisolated` members that
  re-enter the actor via unstructured tasks, destroying the delegate-callback
  ordering guarantees the class depends on. **[skill: Concurrency Tool Selection —
  actors are for shared mutable state you can afford to `await`; and "Optimize for
  the smallest safe change"]**.
- **The serial-`OperationQueue` delegate pattern (commit `9e30154`) stays.** Why it
  exists: `URLSession` delivers delegate callbacks on its `delegateQueue`; before
  `9e30154` that was the main queue (contention + priority problems), now a dedicated
  serial queue (`maxConcurrentOperationCount = 1`) preserves the strict callback
  ordering URLSession promises per task while staying off the main thread. Why it
  should *not* become actor-based under strict concurrency: delegate methods like
  `urlSession(_:dataTask:didReceive:completionHandler:)` must invoke their
  completion handlers promptly and in order; hopping onto an actor makes every
  callback an unordered async enqueue, and `needNewBodyStream`'s reply would race
  the resend machinery. Queue-confined + lock-guarded state is the correct model
  for a pre-async-delegate-API deployment floor (iOS 12; `URLSessionTask.delegate`
  per-task requires iOS 15 — see the existing TODO on lines 31–33).

Edit: replace the class doc's last sentence with an explicit safety contract:

```swift
/// Safety: `@unchecked Sendable` because (a) checked `Sendable` requires `final`
/// and this class is deliberately `open` for subclassing, and (b) its mutable
/// state (`metricsClosures`, `streams`) is only ever accessed within
/// `self.lock.perform`. Delegate callbacks are serialized by the dedicated
/// serial `OperationQueue` passed to `URLSession`, preserving per-task callback
/// ordering. Subclasses must provide their own synchronization for any state
/// they add. `deinit` audit: `finishTasksAndInvalidate()` is thread-safe and
/// callable from any thread.
```

No functional change in this file. (A `Locked<Storage>` consolidation of the two
dictionaries was considered and rejected for this migration: it does not remove the
`@unchecked`, and minimal-change wins.)

### 4.8 `URLSessionDelegateWrapper` (same file) — keep, comment

`weak var client` must be a mutable `var` (weak references cannot be `let`), so
checked conformance is impossible. Add:

```swift
/// Safety: `@unchecked Sendable` because the only stored property is a `weak var`
/// (weak refs cannot be `let`), assigned once immediately after the client's
/// `init` and only read thereafter; reads of a weak reference are atomic.
```

### 4.9 Phase 2 verification

`swift build` → warning count still exactly 4 (all NIOHTTPClient). Then §10.1 full
suite, with particular attention to:
- `make testconformance` **urlsession** config (exercises `URLSessionStream`,
  `TimeoutTimer`, `PendingRequestCallbacks` under real streaming), and
- `make testunit` (TimeoutTests, InterceptorChainIterationTests, URLSessionStreamTests).

---

## 5. Phase 3 — `ConnectNIO`: drive warnings to zero

### 5.1 The four warnings (baseline, verified)

```
NIOHTTPClient.swift:85:41  conformance of 'NIOSSLHandler' to 'Sendable' is unavailable
NIOHTTPClient.swift:91:44  conformance of 'HTTP2StreamMultiplexer' to 'Sendable' is unavailable
NIOHTTPClient.swift:238:49 capture of 'handlers' with non-Sendable type '[any ChannelHandler]' in a '@Sendable' closure
NIOHTTPClient.swift:238:49 type 'any ChannelHandler' does not conform to the 'Sendable' protocol
```

Root cause in all cases: non-Sendable NIO channel objects being created *outside*
and moved *into* `@Sendable` event-loop closures, or futures carrying non-Sendable
values through `flatMap`/`map`. NIO's own answer is: do pipeline mutation **on the
event loop** via `ChannelPipeline.SynchronousOperations` (the `channelInitializer`
and `createStreamChannel` closures already run on the channel's event loop). The
file already uses `syncOperations` once (line 200) — this extends the same idiom.

### 5.2 `createBootstrap()` rewrite (fixes 85 + 91)

This is an `open` method; its **signature does not change**, so subclass overrides
and `super.createBootstrap()` callers are unaffected (§6). Replace the
`channelInitializer` closure body:

```swift
.channelInitializer { channel in
    return channel.eventLoop.makeCompletedFuture {
        let sync = channel.pipeline.syncOperations
        if let tlsConfiguration = tlsConfiguration {
            let sslContext = try NIOSSL.NIOSSLContext(configuration: tlsConfiguration)
            let sslHandler = try NIOSSL.NIOSSLClientHandler(
                context: sslContext, serverHostname: host
            )
            try sync.addHandler(sslHandler)
        }
        _ = try sync.configureHTTP2Pipeline(mode: .client) { channel in
            return channel.eventLoop.makeSucceededVoidFuture()
        }
    }
}
```

Implementor notes:
- `tlsConfiguration` (`NIOSSL.TLSConfiguration`, a Sendable struct) and `host`
  (`String`) are the only captures — both Sendable, so the closure is clean.
- The `NIOSSLClientHandler` and the multiplexer never leave the event loop → no
  Sendable crossing → warnings 85/91 gone.
- Error behavior changes slightly: the old code caught errors and returned
  `channel.close(mode: .all)`; `makeCompletedFuture(withResultOf:)` converts a
  `throw` into a failed future, which fails the connect future, which the existing
  `whenComplete` failure path in `connectChannelAndMultiplexerIfNeeded()` already
  handles (logs + fails pending requests). This is acceptable and arguably more
  correct (pending requests are failed instead of a silent close). The conformance
  suite (TLS paths included) is the behavioral gate.
- The multiplexer retrieval path is untouched: `connectChannelAndMultiplexerIfNeeded()`
  already fetches it post-connect via `channel.pipeline.syncOperations.handler(type:
  HTTP2StreamMultiplexer.self)` inside `whenComplete` — verify that call still
  succeeds under the `syncOperations.configureHTTP2Pipeline` setup (it installs the
  same `HTTP2StreamMultiplexer` handler). The `nio` conformance config proves this.
- If `makeCompletedFuture(withResultOf:)` is unavailable in the pinned NIO version
  (it is available well before 2.92.2 — it will not be), the fallback spelling is
  `do { … ; return channel.eventLoop.makeSucceededVoidFuture() } catch { return channel.eventLoop.makeFailedFuture(error) }`.

### 5.3 `startMultiplexChannel` / `createChannelHandlers` rewrite (fixes both 238s)

Both methods are `private` → no API impact. Two changes:

1. Constrain the handler parameter to Sendable (both concrete types,
   `ConnectUnaryChannelHandler` and `ConnectStreamChannelHandler`, are
   `@unchecked Sendable`, so call sites in `unary(...)`/`stream(...)` compile
   unchanged):

```swift
private func startMultiplexChannel(
    for url: URL,
    on eventLoop: NIOCore.EventLoop,
    using multiplexer: NIOHTTP2.HTTP2StreamMultiplexer,
    with connectHandler: any NIOCore.ChannelInboundHandler & Sendable
) {
    let useSSL = self.useSSL
    let timeout = self.timeout
    let promise = eventLoop.makePromise(of: NIOCore.Channel.self)
    multiplexer.createStreamChannel(promise: promise) { channel in
        return channel.eventLoop.makeCompletedFuture {
            var handlers: [NIOCore.ChannelHandler] = [
                useSSL
                ? HTTP2FramePayloadToHTTP1ClientCodec(httpProtocol: .https)
                : HTTP2FramePayloadToHTTP1ClientCodec(httpProtocol: .http),
                connectHandler,
            ]
            if let timeout = timeout {
                handlers.insert(
                    IdleStateHandler(allTimeout: .milliseconds(Int64(timeout * 1_000.0))), at: 0
                )
            }
            try channel.pipeline.syncOperations.addHandlers(handlers)
        }
    }
}
```

2. Delete `createChannelHandlers(with:)` (its body is inlined above so that the
   non-Sendable codec/idle handlers are *created on the event loop* instead of
   captured). Captures are now `useSSL: Bool`, `timeout: TimeInterval?`, and
   `connectHandler` (`& Sendable`) — all clean. (Capturing `self` would also be
   fine — `NIOHTTPClient` is `@unchecked Sendable` — but plain value captures make
   the safety obvious.)

Note: `multiplexer` itself is used only *outside* the closure here (the
`createStreamChannel` call), so its Sendable-unavailability does not re-trigger; it
is stored in `state` guarded by `NIOLock`, which stays as-is.

### 5.4 `@preconcurrency` imports — re-test necessity, date what remains

Per **[skill: Using @preconcurrency — don't use by default; document why; revisit
regularly; the compiler warns when it is unused]**: after §5.2/§5.3, delete
`@preconcurrency` from the `NIOCore` and `NIOSSL` imports and rebuild.

- If the build is clean without them → leave them deleted.
- If diagnostics return (e.g., `EventLoopFuture` variance elsewhere in the target,
  or in `ConnectStreamChannelHandler`/`ConnectUnaryChannelHandler`/`GRPCInterceptor`),
  restore the specific import(s) that are still needed, each with:

```swift
// @preconcurrency: NIO types (e.g. ChannelHandlerContext) are not Sendable and
// are safely event-loop-confined here; checked by NIO at runtime, not by the
// compiler. Re-evaluate on swift-nio major updates. Last checked: 2026-07 (2.92.2).
@preconcurrency import NIOCore
```

The end state must have **zero** warnings either way — an *unused* `@preconcurrency`
itself produces a warning, so the build is self-policing.

### 5.5 Channel handlers + `GRPCInterceptor.Locked` — comments only

`ConnectStreamChannelHandler` / `ConnectUnaryChannelHandler`: keep
`@unchecked Sendable`. All mutable state (`context`, `isClosed`, `pendingData`, …)
is event-loop-confined: every external entry point (`sendData`, `close`, `cancel`)
funnels through `runOnEventLoop`, and `ChannelInboundHandler` callbacks are invoked
by NIO on the event loop. Add to each class:

```swift
/// Safety: `@unchecked Sendable` because all mutable state is confined to
/// `self.eventLoop`: external entry points hop via `runOnEventLoop`, and NIO
/// invokes the `ChannelInboundHandler` callbacks on the event loop.
/// Removal plan: wrap state in `NIOLoopBound` (runtime-asserted confinement) or
/// adopt NIO's async channel APIs if the package's NIO floor rises far enough.
```

Do **not** adopt `NIOLoopBound` in this migration (behavioral no-op, adds churn) —
it is the documented removal plan, not a task.

`GRPCInterceptor.swift`'s private `Locked<T>` (line 283): add a one-line safety
comment mirroring §4.2 (NIOLock-guarded; duplicate of Connect's internal `Locked`
because internal types don't cross module boundaries — do not deduplicate via
`package` access in this migration).

`NIOHTTPClient` class annotation: keep `@unchecked Sendable` (open class, same
finality argument as §4.7; state guarded by `NIOLock`). Add a safety comment in the
same format as §4.7 including the `deinit` audit note from Phase 0. One known
sharp edge to *document but not change*: `sendOrQueueRequest` invokes the `send`
closure while holding `self.lock` — safe today because the closure only enqueues
non-blocking NIO work; flag it in the comment as "must not block or re-enter
`sendOrQueueRequest`".

### 5.6 Phase 3 verification

```bash
swift build 2>&1 | grep "warning:" | grep -v swift-frontend ; echo "exit=$?"
```
Expected: no output, grep exit 1 → **zero warnings package-wide**. Then the full
§10.1 suite; the **nio** conformance config is the critical behavioral gate for
§5.2/§5.3 (TLS handshake, HTTP/2 multiplexing, stream setup all changed shape).
Run `make testconformance` at least 3 consecutive times locally to shake out
timing-sensitive regressions (the historical flake domain).

---

## 6. Public API compatibility analysis

Every change in this plan, classified:

| Change | Surface | Verdict |
|---|---|---|
| `Package.swift` tools 6.0 + `swiftLanguageModes` | SwiftPM consumers | **Non-breaking** (toolchain floor already Xcode 16+ via swift-nio's tools-6.0 manifest, §0.1) |
| `TimeoutTimer`, `ClientOnlyStream`, `PendingRequestCallbacks`, `BidirectionalAsyncStream` restructures | `internal`/`private` | **Non-breaking** (not exported; `ConnectMocks` depends only on public `*Interface` protocols) |
| `URLSessionHTTPClient` | `open` public class | **No signature/annotation change at all** — comments only. Subclass contracts intact (still `open`, still `NSObject`, still `@unchecked Sendable`, delegate methods unchanged) |
| `NIOHTTPClient.createBootstrap()` body | `open` method | **Source-compatible**: signature unchanged; subclasses that override it keep their own behavior; subclasses calling `super` get the new equivalent pipeline. Behavior note in §5.2 (error path) — release-notes-worthy, not source-breaking |
| `NIOHTTPClient.createTLSConfiguration(forHost:)` | `open` method | Untouched |
| `startMultiplexChannel`/`createChannelHandlers` | `private` | Invisible |
| `deinit` shutdown change (Phase 0) | runtime behavior | Strictly a crash fix; `shutdownGracefully` is async where `syncShutdownGracefully` blocked — no API impact |
| Podspec `swift_versions` ['5.0','6.0'] (§7) | CocoaPods consumers | See §7 — chosen precisely to be the least-breaking option |
| Generated-code templates | every consumer's build | **No template output changes** in this plan (§8) → regenerated code is byte-identical; CI's "Ensure no generated diff" job enforces this |

**Explicitly rejected breaking alternatives** (do not implement):
- Making `URLSessionHTTPClient`/`NIOHTTPClient` `final` or actors (§4.7, §5.5) —
  would be semver-major; gain (removing 2 justified `@unchecked`s) does not warrant it.
- Removing the callback API surface to simplify `BidirectionalAsyncStream` — major.
- Deprecation shims / `@preconcurrency public` annotations: **not needed** — since no
  public signature changes, there is nothing to shim. If a future major release
  finalizes the client classes, that release can revisit.

---

## 7. Deployment-target decision & podspec reconciliation

**Decision: keep iOS 12 / macOS 10.15 / tvOS 13 / watchOS 6. Do not raise floors in
this migration.** Reasoning:

- Nothing in this plan *requires* newer OS APIs. The async/await surfaces are
  already availability-gated `@available(iOS 13, *)`; `Lock`/`Locked` remain valid
  at iOS 12; actors used (`UnaryAsyncWrapper`) are already gated.
- The tempting upgrades are pure nice-to-haves, and each is recorded as a "removal
  plan" comment instead: `OSAllocatedUnfairLock` (iOS 16/macOS 13),
  `Synchronization.Mutex` (iOS 18/macOS 15), `URLSessionTask.delegate` per-task
  (iOS 15, existing TODO in `URLSessionHTTPClient`), SE-0371 `isolated deinit`
  (newer runtime). Availability-gated *dual* implementations (e.g., `Lock` backed by
  `OSAllocatedUnfairLock` when available) were considered and rejected: they double
  the untested surface for zero checker benefit — `Lock` stays `@unchecked` either way.
- Raising floors is a consumer-facing product decision belonging to a major
  release, and would have to move both podspecs and the manifest in lockstep.

**Podspec changes (Phase 5):** in `Connect-Swift.podspec` **and**
`Connect-Swift-Mocks.podspec`:

```ruby
spec.swift_versions = ['5.0', '6.0']
```

Mechanics, so the implementor understands the blast radius: CocoaPods sets the pod
target's `SWIFT_VERSION` to the **highest** declared version compatible with the
consumer's constraints. So on modern Xcode, pod consumers silently move from
building Connect sources in Swift 5 mode to Swift 6 mode — safe because Phases 2–4
make the sources warning-free in v6 mode, and language mode is per-module (the
consumer's own code is unaffected). A consumer stuck on an older Xcode (< 16) can
pin back via `supports_swift_versions '5.0'` in their Podfile because `'5.0'`
remains declared — that is why we keep it. Removing `'5.0'` is coupled to removing
`.v5` from `swiftLanguageModes` in some future major release, not now.

Verification for Phase 5: the `ElizaCocoaPodsApp` CI job (`pod install` +
`xcodebuild -workspace ElizaCocoaPodsApp.xcworkspace -scheme ElizaCocoaPodsApp build`)
must stay green; run it locally with the exact ci.yml invocation (§10.2). Note the
example's Podfile consumes the local podspecs via `:path`, so the new
`swift_versions` takes effect immediately.

---

## 8. Phase 4 — Plugins, generated code, mocks, tests

### 8.1 Generated client template (`Plugins/ConnectSwiftPlugin/ConnectClientGenerator.swift`)

Verified current output: service protocols are declared `: Sendable` (line 52) and
implementations `final class …: <Protocol>, Sendable` (line 70) — generated clients
are **checked**-Sendable in the consumer's module and hold only a
`let client: ProtocolClientInterface` (a Sendable existential). A consumer compiling
generated output in their own Swift 6 module gets zero diagnostics — proven by the
`ElizaSwiftPackageApp` CI job, which builds generated code at `SWIFT_VERSION = 6.0`.

**No template changes.** Do not add `@unchecked` anywhere here; do not add
availability churn.

### 8.2 Generated mock template (`Plugins/ConnectMocksPlugin/ConnectMockGenerator.swift`)

Verified current output: mocks are `class …: <Protocol>, @unchecked Sendable` with
the justification comment already emitted into every generated file (lines 65–66 of
the generator: "This class does not handle thread-safe locking, but provides
`@unchecked Sendable` conformance to simplify testing and mocking."). This meets the
acceptance criterion "no `@unchecked Sendable` without an inline justification" *in
consumers' generated code as well*. **No template changes.**

### 8.3 `ConnectMocks` library (`Libraries/ConnectMocks/Mock*.swift`, 6 classes)

Keep all six `@unchecked Sendable`. They are `open` (finality argument again),
deliberately non-thread-safe test doubles with `@Published` mutable state, and their
doc comments already describe the usage model. Edit: append one sentence to each
class doc comment:

```
/// Safety: `@unchecked Sendable` to satisfy `Sendable` protocol requirements in
/// tests; instances are intended to be confined to a single test's context and
/// perform no internal synchronization.
```

### 8.4 Test target

`Tests/UnitTests/ConnectLibraryTests/ConnectTests/TimeoutTests.swift:63`
(`TimeoutHTTPClient`): add
`// Safety: @unchecked Sendable — test double confined to a single test invocation.`

### 8.5 Regeneration + consumer verification

```bash
make buildplugins
make generate
git update-index --refresh --add --remove && git diff-index --quiet HEAD --
```
Expected: **no diff** (templates unchanged). If a diff appears, the implementor has
accidentally changed generator behavior — revert and re-read §8.1/§8.2. Then build
both example apps with the exact ci.yml invocations (§10.2).

---

## 9. Risk register

| # | Risk | Phase | Mitigation / disposition |
|---|---|---|---|
| R1 | **NIOHTTPClient deinit-on-event-loop crash** (unmerged fix `6367acb`). Class of bug invisible to Swift 6 (deinit isolation unchecked). | 0 | Land first (§2). Manual `deinit` audit of all kept-`@unchecked` classes completed in §2. Residual: any *new* `deinit` added later needs the same audit — noted in `NIOHTTPClient`'s safety comment. |
| R2 | **URLSession stream-replay flake** (PR #399 / `d608f78`): `URLSessionStream.requestBodyStream` intentionally returns `nil` on resend → task fails as `cancelled` instead of retrying. | out of scope | **Analysis:** actor isolation does *not* change feasibility — the constraint is URLSession's one-shot bound-stream semantics, not a data race; the `requestBodyStreamVended` flag is already race-free via `Locked`. A real fix is a bounded replay buffer: retain outbound bytes (up to a cap) in `URLSessionStream`, and on `needNewBodyStream` create a *fresh* bound-stream pair, replay the buffer, then continue live writes; must handle buffer-overflow (fall back to today's `nil`) and interaction with gRPC-Web framing. That is a feature, not a migration step — **file as follow-up**; the migration only leaves the state machine better-documented. Mapping the failure to a retryable code instead of `.canceled` is a smaller alternative follow-up. |
| R3 | **TimeoutTimer regressions** — timing bugs have bitten before (`d9eda55` deadlock). | 2 | §4.3 removes the `queue.sync` dual-serialization entirely; behavior table in §4.3; `TimeoutTests` + conformance timeout cases gate. `cancel()`-from-callback reentrancy explicitly preserved (work-item cancel never blocks). |
| R4 | **Interceptor chain**: strict concurrency could surface consumer-side races (interceptor closures capturing non-Sendable state). | n/a | `InterceptorChain` itself is checked-Sendable already (§0.4); its recursion is pure. Known duplicate-callback hazard (NIO firing a response callback twice near timeout) is already defended by `Locked` guards (`hasCompleted`, `UnaryAsyncWrapper.hasResumed` with `os_log` fault). No changes; do not "simplify" the guards. |
| R5 | **NIO pipeline restructure behavior drift** (§5.2 error-path change; §5.3 handler-creation timing). | 3 | Signature-preserving; conformance `nio` config ×3 runs; TLS covered by conformance server. Fallback spelling provided if `makeCompletedFuture` form misbehaves. |
| R6 | **CocoaPods consumers silently flipped to Swift 6 mode** by podspec change. | 5 | Deliberate and safe post-Phase-3 (§7); `'5.0'` retained as escape hatch; ElizaCocoaPodsApp job gates. |
| R7 | **Toolchain skew**: local Xcode 26.6 vs CI 26.4.1 may differ in diagnostics. | all | Baseline captured in Phase 0 *on CI* too (push a draft PR early; compare warning inventory). Any CI-only diagnostics get folded into the phase touching that file. |
| R8 | **Swift 5-mode regression** (CocoaPods path) from new syntax. | 2–4 | Nothing in this plan uses 6-only *syntax* (all changes are valid Swift 5 code); ElizaCocoaPodsApp job is the executable check each phase. |
| R9 | **`swiftLanguageModes` rename typo'd or `.v5` dropped**, silently changing consumer builds. | 1 | §3.1 exact edit; §3.4 verification asserts `-swift-version 6` on all targets. |

---

## 10. Verification gates

### 10.1 Per-phase gate suite (run after every phase; all must pass)

```bash
# 1. Package builds, and the warning inventory matches the phase's expectation
#    (Phases 0–2: exactly the 4 NIOHTTPClient warnings; Phase 3 onward: zero)
swift build 2>&1 | grep "warning:" | grep -v swift-frontend | sort -u

# 2. Unit tests (spawns the Go reference server; requires Go, per ci.yml)
make testunit

# 3. Conformance suite, both HTTP clients (one-time setup: make installconformancerunner)
make testconformance

# 4. Four platform builds (exact ci.yml invocations)
xcodebuild -scheme Connect-Package -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' | xcbeautify
xcodebuild -scheme Connect-Package -destination 'platform=macOS' | xcbeautify
xcodebuild -scheme Connect-Package -destination 'platform=tvOS Simulator,name=Apple TV 4K (3rd generation),OS=latest' | xcbeautify
xcodebuild -scheme Connect-Package -destination 'platform=watchOS Simulator,name=Apple Watch Ultra 3 (49mm),OS=latest' | xcbeautify

# 5. Lint (CI runs swiftlint 0.58.2 --strict)
swiftlint lint --strict

# 6. Codegen invariant (Phases 1+; requires buf)
make buildplugins && make generate && git update-index --refresh --add --remove && git diff-index --quiet HEAD --
```

### 10.2 Example apps (Phases 1, 4, 5 at minimum; exact ci.yml invocations)

```bash
cd Examples/ElizaSwiftPackageApp && \
  xcodebuild -scheme ElizaSwiftPackageApp build CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO | xcbeautify

cd Examples/ElizaCocoaPodsApp && pod install && \
  xcodebuild -workspace ElizaCocoaPodsApp.xcworkspace -scheme ElizaCocoaPodsApp build CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO | xcbeautify
```

### 10.3 Phase 6 — permanent CI enforcement

Once Phase 3's zero-warning state lands, add enforcement so it cannot rot. Preferred
mechanism (root-package targets only; does not affect dependencies):

```yaml
  build-strict-concurrency:
    runs-on: macos-26
    steps:
      - uses: actions/checkout@v7
      - name: Build with warnings as errors
        run: swift build -Xswiftc -warnings-as-errors
```

If any benign non-concurrency warning ever makes `-warnings-as-errors` untenable,
the fallback is the grep-based assertion from §10.1 step 1 wrapped in a `make
strictbuild` target. Either way, the job must fail on a reintroduced concurrency
warning.

### 10.4 CI job inventory that must stay green throughout (from ci.yml)

`build-eliza-cocoapods-example`, `build-eliza-swiftpm-example`, `build-library-ios`,
`build-library-macos`, `build-library-tvos`, `build-library-watchos`,
`build-plugin-and-generate`, `run-conformance-tests`, `run-unit-tests`,
`run-swiftlint`, `validate-license-headers` — plus the new
`build-strict-concurrency` after Phase 6.

---

## 11. Final acceptance criteria

The migration is complete when **all** of the following hold on one commit:

1. `Package.swift` declares `// swift-tools-version:6.0` and
   `swiftLanguageModes: [.v6, .v5]`; `swift build -v` shows `-swift-version 6` for
   every target (all 6 library/plugin targets, the conformance executable, and both
   test targets).
2. `swift build` produces **zero warnings** (equivalently:
   `swift build -Xswiftc -warnings-as-errors` succeeds) — i.e., every library and
   plugin target is clean under Swift 6 language mode's complete strict-concurrency
   checking with no reliance on warning-downgrades.
3. `@unchecked Sendable` count in `Libraries/` + `Plugins/` is exactly the 17 kept
   sites from §0.3 (20 minus the 3 removals in §4.3/§4.4/§4.6), and **every one has
   an inline safety-invariant + removal-plan comment**; the two test-target doubles
   are commented; the only uncommented occurrences live in swift-protobuf-emitted
   `*.pb.swift` files.
4. `@preconcurrency` imports are either gone or individually justified with dated
   comments per §5.4, and none is flagged "unused" by the compiler.
5. Generated output from both plugins is byte-identical to the committed
   `GeneratedSources` (CI `build-plugin-and-generate` green), and that output
   compiles warning-free inside a Swift-6-mode consumer (ElizaSwiftPackageApp job
   green at `SWIFT_VERSION = 6.0`).
6. Both podspecs declare `swift_versions = ['5.0', '6.0']`; ElizaCocoaPodsApp job
   green (which now builds the pod sources in Swift 6 mode).
7. All CI jobs in §10.4 green, including 3 consecutive green
   `run-conformance-tests` runs (flake check) with the Phase 0 crash fix included.
8. Deployment targets unchanged (iOS 12/macOS 10.15/tvOS 13/watchOS 6) in both the
   manifest and both podspecs.

## 12. Explicit non-goals (do not do these while implementing)

- No `ExistentialAny`/other upcoming-feature adoption (§3.1).
- No `NIOLoopBound`, no NIO async-API adoption (§5.5).
- No actorization of `URLSessionHTTPClient`/`NIOHTTPClient` (§4.7).
- No deduplication of the two `Locked` types across modules (§5.5).
- No deployment-target changes (§7).
- No fix for the request-body-replay flake (§9 R2 — file as follow-up).
- No removal of the callback-based API surface.
- No hand-edits to anything under a `GeneratedSources/` directory.
