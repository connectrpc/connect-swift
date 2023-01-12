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
git remote add upstream https://github.com/bufbuild/connect-swift.git
git fetch upstream
```

You'll also need to **install Xcode** and install Buf's CLI:

```sh
brew install bufbuild/buf/buf
```

This project uses Swift Package Manager for development and
distribution. To get started contributing locally:

- Open Xcode
- Click `Open...` and select the root `connect-swift` repo directory
- Xcode will automatically read the [`Package.swift`](../Package.swift)
  file and open the project

## Developing the Library

The Connect library's source code is available in the [`Connect`](../Connect)
directory.

The easiest way to contribute to the library is to
[open the Xcode project](#setup) and
[run the tests](#running-tests) after making changes before finally
[submitting them](#submitting-changes).

## Developing the Generator

The source code for the plugin that is used to generate Connect-compatible
services and RPCs is in the
[`protoc-gen-connect-swift`](../protoc-gen-connect-swift) directory.

The plugin utilizes the [`SwiftProtobufPluginLibrary`][swift-plugin-library]
module from SwiftProtobuf which provides types for interacting with the input
`.proto` files and writing to `stdout`/`stderr` as expected by `protoc`.

To build the generator plugin, use Xcode or the following command:

```sh
make buildplugin
```

## Generating Code

To build the plugin and run it against the directories specified in
[`buf.work.yaml`](../buf.work.yaml)
using the [local plugin](../protoc-gen-connect-swift) and Buf:

```sh
make buildplugin # Compile the plugin
make generate # Run buf generate - uses buf.gen.yaml
```

Outputted code will be available in the [`Generated`](../Generated) directory.

# Running Tests

A test server is used to run [crosstests](../ConnectTests) -
integration tests which validate the behavior of the `Connect` library with
various protocols. **Starting the server requires Docker,
so ensure that you have Docker installed before proceeding.**

To start the server and run tests using the command line:

```sh
make test
```

If you prefer to run the tests using Xcode, you can manually start the server:

```sh
make crosstestserverrun
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
plugin, also ensure that any [generated diff](#generating-code) is checked in.

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

[cla]: https://cla-assistant.io/bufbuild/connect-swift
[commit-message]: http://tbaggery.com/2008/04/19/a-note-about-git-commit-messages.html
[fork]: https://github.com/bufbuild/connect-swift/fork
[open-issue]: https://github.com/bufbuild/connect-swift/issues/new
[swift-plugin-library]: https://github.com/apple/swift-protobuf/tree/main/Sources/SwiftProtobufPluginLibrary
