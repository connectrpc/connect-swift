# connect-swift

## Prerequisites

In order to develop with this repository, install Xcode and
complete the following setup:

```sh
# Grab the connect-crosstest submodule:
git submodule update --init

# Ensure you have required dependencies installed:
brew install buf
```

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

## <a name="swift-setup"></a>Swift (iOS) setup

This project uses Swift Package Manager for development, building, and
distribution. To open the project and start using it:

- Open Xcode
- Click `Open...` and select the root `connect-swift` repo directory
- Xcode will automatically read the [`Package.swift`](./Package.swift) file and open the project

## Generate code from protos

To build the plugin and run it against the [`./protos`](./protos) directory
using Buf:

```sh
make build-connect-plugin # Compile the plugin
make generate # Run buf generate - uses buf.gen.yaml
```

Outputted code will be available in `./gen`.

## Build and run example apps

Tests and example apps depend on outputs in `./gen`.

Example apps are available in
[`./examples`](./examples), and can be opened and
built using Xcode.

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
