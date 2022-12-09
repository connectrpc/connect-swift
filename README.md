# connect-swift

## Prerequisites

In order to develop with this repository, complete the following setup:

```sh
# To grab connect-crosstest submodule:
git submodule update --init

# Ensure you have required dependencies installed:
brew install bazelisk buf
```

## Go development

To make changes to the Go [plugins](./cmd) that are used to generate code,
ensure the required dependencies are installed:

```sh
go mod vendor
```

If you have issues with GoLand indexing dependencies correctly, you can try
removing the `.idea` directory in the project directory and re-opening GoLand.

To build the plugins, you can use:

```sh
make build
```

## <a name="swift-setup"></a>Swift (iOS) setup

Ensure that you have **Xcode 14.1 (or above)** installed and that `xcode-select` is set up:

```sh
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer # Or your Xcode location
```

To generate an Xcode project with schemes for all relevant sources:

```sh
make xcodeproj # Generate a .xcodeproj
xed . # Open the generated .xcodeproj
```

## Generate code from protos

Build both plugins and invoke them against the [protos](./protos) directory
using Buf:

```sh
make build # Compile the plugins
make generate # Run buf generate - uses buf.gen.yaml
```

Outputted code will be available in `./gen`.

## Build and run example apps

Tests and example apps depend on targets in `./gen`.

**Using Xcode:**

Generate the `.xcodeproj` using the [steps above](#swift-setup),
select the app target and an iOS simulator, then click Run.

**Using command line:**

```sh
make swift-example
```

## Run Connect cross tests & test service

The test service is used by the client cross tests.
To run it locally **without requiring a TLS certificate**:

```sh
cd connect-crosstest
git apply ../crosstests/local.patch
go build -o testserver cmd/serverconnect/main.go
./testserver --h1port=8080 --h2port=8081
```

Run the cross tests:

```sh
bazelisk test //crosstests:crosstests
```

## Bazel

The Bazel build system is used to compile all the code in this repository.

The version in use is pinned in the [`.bazelversion`](./.bazelversion) file,
and it's automatically consumed by `bazelisk`.

If you run into lint failures with Bazel files, you can run this to fix them:

```sh
make buildifier-fix
```
