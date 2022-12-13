# connect-swift

- [Get started](#get-started)
  * [Set up code generation](#set-up-code-generation)
  * [Integrate with Swift Package Manager](#integrate-with-swift-package-manager)
  * [Integrate with CocoaPods](#integrate-with-cocoapods)
- [Examples](#examples)
  * [Build and run example apps](#build-and-run-example-apps)
- [Contributing](#contributing)
  * [Development setup](#development-setup)
  * [Swift development](#swift-development)
  * [Generate code from protos](#generate-code-from-protos)
  * [Go development](#go-development)
- [Tests](#tests)
  * [Run Connect crosstests & test service](#run-connect-crosstests--test-service)
    + [Using Docker](#using-docker)
    + [Without Docker (and no SSL)](#without-docker-and-no-ssl)

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
    out: gen/proto/connectswift # Or your target output directory

```

3. Add a `buf.work.yaml` file to your project which specifies the input directories for your `.proto` files:
```yaml
version: v1
directories:
  - protos # Or wherever your .proto files live
```

4. Run `make generate` (or `buf generate`), and you should see the outputted files!
5. Now that you have generated models + APIs from your `.proto` files, you'll need to integrate the runtime using one of the methods below.

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

## Generate code from protos

To build the plugin and run it against the [`./protos`](./protos) directory
using the [local plugin](./protoc-gen-connect-swift) and Buf:

```sh
make build-connect-plugin # Compile the plugin
make generate # Run buf generate - uses buf.gen.yaml
```

Outputted code will be available in `./gen`.

## Go development

To make changes to the Go [plugin](./protoc-gen-connect-swift)
that is used to generate code,
ensure the required dependencies are installed:

```sh
go mod vendor
```

If you have issues with GoLand indexing dependencies correctly, you can try
removing the `.idea` directory in the project directory and re-opening GoLand.

To build the connect-swift generator plugin, you can use:

```sh
make build-connect-plugin
```

# Tests

## Run Connect crosstests & test service

A test service is used to run crosstests
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

### Without Docker (and no SSL)

Alternatively, you can run the local service without
requiring a TLS certificate. This requires a patch to be applied before
starting the service:

```sh
cd connect-crosstest
git apply ../crosstests/local.patch
go build -o testserver cmd/serverconnect/main.go
./testserver --h1port=8080 --h2port=8081
```

**You'll then need to change `http` to `https` in
[`Crosstests.swift`](./crosstests/Crosstests.swift).**

Finally, run the crosstests:

```sh
swift test
```
