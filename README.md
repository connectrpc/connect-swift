# connect-swift

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
  * [Run Connect crosstests & test service](#run-connect-crosstests---test-service)
    + [Using Docker](#using-docker)
    + [Without Docker (no SSL)](#without-docker--no-ssl-)

# Get started

## Set up code generation

The easiest way to get started using connect-swift is to use
[Buf's remote generation](https://docs.buf.build/bsr/remote-plugins/overview):

1. Install Buf's CLI (`brew install buf`).
2. Add a `buf.gen.yaml` file to your project which contains a configuration for running both the [SwiftProtobuf](https://github.com/apple/swift-protobuf) and connect-swift generators:

```yaml
version: v1
managed:
  enabled: true
  optimize_for: LITE_RUNTIME
  go_package_prefix:
    default: plugins/protoc-gen-connect-swift # Replace with your package (can be anything)
plugins:
  - plugin: buf.build/apple/swift
    opt: Visibility=Public
    out: gen/proto/swift-protobuf # Or your target output directory
  - remote: buf.build/mrebello/plugins/connect-swift
    opt: Visibility=Public # See "custom configuration" section in docs below
    out: gen/proto/connect-swift # Or your target output directory
```

3. Add a `buf.work.yaml` file to your project which specifies the input directories for your `.proto` files:
```yaml
version: v1
directories:
  - protos # Or wherever your .proto files live
```

4. Run `make generate` (or `buf generate`), and you should see the outputted files!
5. Now that you have generated models + APIs from your `.proto` files, you'll need to integrate the runtime using one of the methods below.

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
| `IncludeAsyncAwait` | Bool | `false` | No | No | If `true`, generates RPC function calls that provide Swift `async`/`await` interfaces instead of closure-based callbacks |
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

We have an [example app](#examples) that uses this exact setup that you can
also take a look at below.

## Integrate with CocoaPods

TODO

# Examples

## Build and run example apps

Tests and example apps depend on outputs in `./gen`.

Example apps are available in
[`./examples`](./examples), and can be opened and built using Xcode.

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
git submodule update --init # Set up the connect-crosstest submodule
brew install buf
```

## Swift development

This project uses Swift Package Manager for development, building, and
distribution. To open the project and start using it:

- Open Xcode
- Click `Open...` and select the root `connect-swift` repo directory
- Xcode will automatically read the [`Package.swift`](./Package.swift) file and open the project

### Developing the library

The Connect library's source code is available in the [`./library`](./library)
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
make build-connect-plugin
```

## Generate code from protos

To build the plugin and run it against the [`./protos`](./protos) directory
using the [local plugin](./protoc-gen-connect-swift) and Buf:

```sh
make build-connect-plugin # Compile the plugin
make generate # Run buf generate - uses buf.gen.yaml
```

Outputted code will be available in `./gen`.

# Tests

## Run Connect crosstests & test service

A test service is used to run [crosstests](./tests)
(integration tests which validate the behavior of the `Connect` library with
various protocols).

Crosstests can be run using the command line or using Xcode. Before running
them, you'll need to start the test service using one of the methods below:

### Using Docker

Running the crosstest service using Docker allows the tests to run using SSL:

```sh
make cross-test-server-run
swift test
make cross-test-server-stop
```

### Without Docker (no SSL)

Alternatively, you can run the local service without
requiring a TLS certificate. This requires a patch to be applied before
starting the service:

```sh
cd connect-crosstest
git apply ../tests/crosstests-local.patch
go build -o testserver cmd/serverconnect/main.go
./testserver --h1port=8080 --h2port=8081
```

**You'll then need to change `http` to `https` in
[`Crosstests.swift`](./tests/Crosstests.swift).**

Finally, run the crosstests:

```sh
swift test
```
