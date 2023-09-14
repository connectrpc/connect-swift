Contributing
============

We'd love your help making Connect better!

If you'd like to add new public APIs, please [open an issue][open-issue]
describing your proposal &mdash; discussing API changes ahead of time makes
pull request review much smoother. In your issue, pull request, and any other
communications, please remember to treat your fellow contributors with
respect!

Note that you'll need to sign [Buf's Contributor License Agreement][cla]
before we can accept any of your contributions. If necessary, a bot will remind
you to accept the CLA when you open your pull request.

## Setup

[Fork][fork], then clone the repository:

```sh
git clone git@github.com:your_github_username/connect-swift.git
cd connect-swift
git remote add upstream https://github.com/connectrpc/connect-swift.git
git fetch upstream
```

You'll also need to **install Xcode and Buf's CLI**:

```sh
brew install bufbuild/buf/buf
```

This project uses Swift Package Manager for development and
distribution. To get started contributing locally:

- Open Xcode.
- Click `Open...` and select the root `connect-swift` repo directory.
- Xcode will automatically read the [`Package.swift`](../Package.swift)
  file and open the project.

## Developing the Library

The Connect library's source code is available in the
[`Libraries/Connect`](../Libraries/Connect) directory.

The easiest way to contribute to the library is to
[open the Xcode project](#setup) and
[run the tests](#running-tests) after making changes before finally
[submitting them](#submitting-changes).

## Developing the Generator

The source code for the plugin that generates Connect-compatible
services and RPCs is in the
[`Plugins/ConnectSwiftPlugin`](../Plugins/ConnectSwiftPlugin) directory,
and the plugin responsible for generating mock implementations is in
[`Plugins/ConnectMocksPlugin`](../Plugins/ConnectMocksPlugin).

The plugins utilize the [`SwiftProtobufPluginLibrary`][swift-plugin-library]
module from SwiftProtobuf which provides types for interacting with the input
`.proto` files and writing to `stdout`/`stderr` as expected by `protoc`.

To build the generator plugins, use Xcode or the following command:

```sh
make buildplugins
```

## Generating Code

To build the [local plugins](../Plugins) and run them against the directories
specified in the repository's `buf.work.yaml` files using Buf:

```sh
make buildplugins # Compile the plugins
make generate # Run buf generate
```

Outputted code will be available in the `out` directories specified by
`buf.gen.yaml` files in the repository.

## Running Tests

A test server is used to run
[conformance](../Tests/ConnectLibraryTests/ConnectConformance) -
integration tests which validate the behavior of the `Connect` library with
various protocols. **Starting the server requires Docker,
so ensure that you have Docker installed before proceeding.**

To start the server and run tests using the command line:

```sh
make test
```

If you prefer to run the tests using Xcode, you can manually start the server:

```sh
make conformanceserverrun
```

## Linting

Connect-Swift uses [SwiftLint][swiftlint] for linting `.swift` files. To
install the linter locally, see the [instructions][swiftlint-install]. Ensure
that the version you install matches the version being used on the
[`run-swiftlint` CI job](./workflows/ci.yaml).

You can run the linter by executing the following in the **root of the repo**:

```sh
swiftlint lint
```

## Submitting Changes

Start by creating a new branch for your changes:

```sh
git checkout main
git fetch upstream
git rebase upstream/main
git checkout -b cool_new_feature
```

Ensure that [the tests pass](#running-tests). If you are changing the generator
plugins, also ensure that any [generated diff](#generating-code) is checked in.

```sh
git commit -a
git push origin cool_new_feature
```

Then use the GitHub UI to open a pull request.

At this point, you're waiting on us to review your changes. We *try* to respond
to issues and pull requests within a few business days, and we may suggest some
improvements or alternatives. Once your changes are approved, one of the
project maintainers will merge them.

We're much more likely to approve your changes if you:

* Add tests for new functionality.
* Write a [good commit message][commit-message].
* Maintain backward compatibility.

## Updating Dependencies

To update dependencies such as `SwiftProtobuf` in this repository:

1. Update the main [library's `Package.swift` file](../Package.swift) with the new version.
2. Open the project to ensure the [`Package.resolved` file](../Package.resolved) gets updated by Xcode.
3. Update the versions in both the [`Connect-Swift.podspec`](../Connect-Swift.podspec) and
   [`Connect-Swift-Mocks.podspec`](../Connect-Swift-Mocks.podspec) files.
4. Open the [Swift package example app](../Examples/ElizaSwiftPackageApp) to ensure its `Package.resolved` file gets updated.
5. Run `pod update` in the [CocoaPods example app's directory](../Examples/ElizaCocoaPodsApp).
6. Update remote plugin entries (such as `buf.build/apple/swift`) in all `buf.gen.yaml` files to be in sync with their respective runtime libraries.
7. Run `make generate` to apply any generated diffs from the newly updated plugins.

## Releasing

Releases should be tagged in `x.y.z` SemVer format.

1. Create a new GitHub release.
2. Update both [`Connect-Swift.podspec`](../Connect-Swift.podspec) and
   [`Connect-Swift-Mocks.podspec`](../Connect-Swift-Mocks.podspec) to reflect
   the newly tagged version.
3. Run `cd Examples/ElizaCocoaPodsApp && pod update` to update the example CocoaPods app.
4. Submit a PR with these changes.
5. Push both specs to CocoaPods:

```sh
pod trunk push Connect-Swift.podspec
pod repo update
pod trunk push Connect-Swift-Mocks.podspec
```

Note: If pushing the mocks podspec fails because CocoaPods cannot find the new
`Connect-Swift` podspec in the specs repo, you may have to wait ~30 min
for it to populate before trying again.

[cla]: https://cla-assistant.io/connectrpc/connect-swift
[commit-message]: http://tbaggery.com/2008/04/19/a-note-about-git-commit-messages.html
[fork]: https://github.com/connectrpc/connect-swift/fork
[open-issue]: https://github.com/connectrpc/connect-swift/issues/new
[swiftlint]: https://github.com/realm/SwiftLint
[swiftlint-install]: https://github.com/realm/SwiftLint#installation
[swift-plugin-library]: https://github.com/apple/swift-protobuf/tree/main/Sources/SwiftProtobufPluginLibrary
