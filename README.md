# connect-swift

[![Build](https://github.com/bufbuild/connect-swift/actions/workflows/ci.yaml/badge.svg?branch=main)](https://github.com/bufbuild/connect-swift/actions/workflows/ci.yaml)

- [Get started](#get-started)
  * [Set up code generation](#set-up-code-generation)
    + [Custom configuration](#custom-configuration)
  * [Integrate with Swift Package Manager](#integrate-with-swift-package-manager)
  * [Integrate with CocoaPods](#integrate-with-cocoapods)
- [Examples](#examples)
  * [Build and run example apps](#build-and-run-example-apps)
  * [Writing an interceptor](#writing-an-interceptor)
- [Contributing](#contributing)
  * [Development setup](#development-setup)
  * [Swift development](#swift-development)
    + [Developing the library](#developing-the-library)
    + [Developing the generator plugin](#developing-the-generator-plugin)
  * [Generate code from protos](#generate-code-from-protos)
- [Tests](#tests)
  * [Run Connect crosstests & test server](#run-connect-crosstests---test-server)

# Get started

## Set up code generation

The easiest way to get started using connect-swift is to use
[Buf's remote generation](https://docs.buf.build/bsr/remote-plugins/overview):

1. Install Buf's CLI (`brew install bufbuild/buf/buf`).
2. Add a `buf.gen.yaml` file to your project which contains a configuration for running both the [SwiftProtobuf](https://github.com/apple/swift-protobuf) and connect-swift generators:

```yaml
version: v1
managed:
  enabled: true
plugins:
  - plugin: buf.build/apple/swift
    opt: Visibility=Public
    out: Generated/swift-protobuf # Or your target output directory
  - remote: buf.build/mrebello/plugins/connect-swift
    opt: GenerateAsyncMethods=true,GenerateCallbackMethods=true,Visibility=Public # See "custom configuration" section in docs below
    out: Generated/connect-swift # Or your target output directory
```

3. Add a `buf.work.yaml` file to your project which specifies the input directories for your `.proto` files:
```yaml
version: v1
directories:
  - proto # Or wherever your .proto files live
```

4. Run `make generate` (or `buf generate`), and you should see the outputted files!
5. Now that you have generated models & APIs from your `.proto` files, you'll need to integrate the runtime using one of the methods below.

### Custom configuration

We generally try to support the
[same generator options that SwiftProtobuf supports](https://github.com/apple/swift-protobuf/blob/master/Documentation/PLUGIN.md)
such as `Visibility`, `ProtoPathModuleMappings`, etc.
when it makes sense to do so. Additionally, there are other options which may be specified
that are specific to the `protoc-gen-connect-swift` plugin.

| **Option** | **Type** | **Default** | **Repeatable** | **Supported by SwiftProtobuf** | **Details** |
|:---:|:---:|:---:|:---:|:---:|:---:|
| `ExtraModuleImports` | String | None | Yes | No | Allows for specifying additional modules that generated Connect sources should import |
| `FileNaming` | String | `FullPath` | No | Yes | [Documentation](https://github.com/apple/swift-protobuf/blob/main/Documentation/PLUGIN.md#generation-option-filenaming---naming-of-generated-sources) |
| `GenerateAsyncMethods` | Bool | `true` | No | No | If `true`, generates RPC functions that provide Swift `async`/`await` interfaces |
| `GenerateAsyncMocks` | Bool | `false` | No | No | If `true`, generates mock classes and methods for every service and RPC. These depend on `ConnectMocks` and can be used for testing when `GenerateAsyncMethods=true` |
| `GenerateCallbackMethods` | Bool | `true` | No | No | If `true`, generates RPC functions that provide closure-based callback interfaces |
| `GenerateCallbackMocks` | Bool | `false` | No | No | If `true`, generates mock classes and methods for every service and RPC. These depend on `ConnectMocks` and can be used for testing when `GenerateCallbackMethods=true` |
| `KeepMethodCasing` | Bool | `false` | No | No | If `true`, generated RPC function names will match the `rpc` specified in the `.proto` file (instead of being lower-camel-cased) |
| `ProtoPathModuleMappings` | Custom | None | No | Yes | [Documentation](https://github.com/apple/swift-protobuf/blob/main/Documentation/PLUGIN.md#generation-option-protopathmodulemappings---swift-module-names-for-proto-paths) |
| `SwiftProtobufModuleName` | String | `SwiftProtobuf` | No | No | Allows for overriding the `SwiftProtobuf` module name in `import` statements. Useful if the `SwiftProtobuf` dependency is being renamed in custom build configurations |
| `Visibility` | String | `Internal` | No | Yes | [Documentation](https://github.com/apple/swift-protobuf/blob/main/Documentation/PLUGIN.md#generation-option-visibility---visibility-of-generated-types) |

## Integrate with Swift Package Manager

The easiest way to integrate with connect-swift is to depend on the `Connect`
package specified in [`Package.swift`](./Package.swift), as you would any
other Swift package.

Apple has documentation for how to do this
[here](https://developer.apple.com/documentation/xcode/adding-package-dependencies-to-your-app).

Once you've added the `Connect` dependency (and its transitive dependency
on `SwiftProtobuf`), add the generated `.swift` files from the code generation
step, and your project should build!

For an example of integrating `Connect` via Swift Package Manager,
see the [`ElizaSwiftPackageApp`](./ConnectExamples/ElizaSwiftPackageApp).

## Integrate with CocoaPods

Although Swift Package Manager is the preferred distribution method for
the Connect library, we also provide a [podspec](./Connect-Swift.podspec) for
CocoaPods support.

To integrate using CocoaPods, add this line to your `Podfile`:

```rb
# Use the current version (automatically pinned in Podfile.lock after):
pod 'Connect-Swift'

# Or pin a specific version:
pod 'Connect-Swift', '~> x.y.z'
```

You can then use the library by adding `import Connect` to your sources.

For an example of integrating `Connect` via CocoaPods,
see the [`ElizaCocoaPodsApp`](./ConnectExamples/ElizaCocoaPodsApp).

# Examples

## Build and run example apps

Tests and example apps depend on outputs in `./Generated`.

Example apps are available in
[`./ConnectExamples`](./ConnectExamples), and can be opened and built using
Xcode.

## Writing an interceptor

Interceptors are a powerful way to observe and mutate outbound and inbound
headers, data, trailers, and errors both for unary APIs and streams.

An interceptor is instantiated once per request, and provides a set of
closures that are invoked by the client during the lifecycle of that request.
Each closure provides the ability for the interceptor to observe and store
state, as well as the option to mutate the outbound or inbound content.

For example, here is an interceptor that adds an `Authorization` header to
all outbound requests to `demo.connect.build`:

```swift
import Connect

/// Interceptor that adds an `Authorization` header to outbound
/// requests to `demo.connect.build`.
struct ExampleAuthInterceptor: Interceptor {
    init(config: ProtocolClientConfig) {...}

    func unaryFunction() -> UnaryFunction {
        return UnaryFunction(
            requestFunction: { request in
                if request.target.host != "demo.connect.build" {
                    return request
                }

                var headers = request.headers
                headers["Authorization"] = ["SOME_USER_TOKEN"]
                return HTTPRequest(
                    target: request.target,
                    contentType: request.contentType,
                    headers: headers,
                    message: request.message
                )
            },
            responseFunction: { $0 } // Return the response as-is
        )
    }

    func streamFunction() -> StreamFunction {
        return StreamFunction(...)
    }
}
```

Interceptor(s) are then registered with the `ProtocolClient` on initialization:

```swift
let client = ProtocolClient(
    target: "https://demo.connect.build",
    httpClient: URLSessionHTTPClient(),
    ProtoClientOption(),
    ConnectClientOption(),
    InterceptorsOption(interceptors: [ExampleAuthInterceptor.init])
)
```

# Contributing

## Development setup

In order to develop with this repository, **install Xcode** and
complete the following setup:

```sh
brew install bufbuild/buf/buf
```

## Swift development

This project uses Swift Package Manager for development, building, and
distribution. To open the project and start using it:

- Open Xcode
- Click `Open...` and select the root `connect-swift` repo directory
- Xcode will automatically read the [`Package.swift`](./Package.swift) file and open the project

### Developing the library

The Connect library's source code is available in the [`./Connect`](./Connect)
directory.

The easiest way to contribute to the library is to
[open the Xcode project](#swift-development) and
[run the tests](#tests) after making changes.

### Developing the generator plugin

The source code for the plugin that is used to generate Connect-compatible
services and RPCs is in the
[`./protoc-gen-connect-swift`](./protoc-gen-connect-swift) directory.

The plugin utilizes the
[`SwiftProtobufPluginLibrary`](https://github.com/apple/swift-protobuf/tree/main/Sources/SwiftProtobufPluginLibrary)
module from SwiftProtobuf which provides types for interacting with the input
`.proto` files and writing to `stdout`/`stderr` as expected by `protoc`.

To build the connect-swift generator plugin, use Xcode or
the following command:

```sh
make buildplugin
```

## Generate code from protos

To build the plugin and run it against the directories specified in
[`buf.work.yaml`](./buf.work.yaml)
using the [local plugin](./protoc-gen-connect-swift) and Buf:

```sh
make buildplugin # Compile the plugin
make generate # Run buf generate - uses buf.gen.yaml
```

Outputted code will be available in `./Generated`.

# Tests

## Run Connect crosstests & test server

A test server is used to run [crosstests](./ConnectTests)
(integration tests which validate the behavior of the `Connect` library with
various protocols). **Starting the server requires Docker,
so ensure that you have Docker installed before proceeding.**

To start the server and run tests using the command line:

```sh
make test
```

If you prefer to run the tests using Xcode, you can manually start the server:

```sh
make crosstestserverrun
```
