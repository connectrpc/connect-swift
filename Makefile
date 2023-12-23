# See https://tech.davis-hansson.com/p/make/
SHELL := bash
.DELETE_ON_ERROR:
.SHELLFLAGS := -eu -o pipefail -c
.DEFAULT_GOAL := all
MAKEFLAGS += --warn-undefined-variables
MAKEFLAGS += --no-builtin-rules
MAKEFLAGS += --no-print-directory
BIN := .tmp/bin
LICENSE_HEADER_YEAR_RANGE := 2022-2023
CONFORMANCE_PROTO_REF := 8ab24b156f5d3f8e7824b85732fa9765ab084879
CONFORMANCE_RUNNER_TAG := v1.0.0-rc2
EXAMPLES_PROTO_REF := e74547031f662f81a62f5e95ebaa9f7037e0c41b
LICENSE_HEADER_VERSION := v1.12.0
LICENSE_IGNORE := -e Package.swift \
    -e $(BIN)\/ \
    -e Examples/ElizaSharedSources/GeneratedSources\/ \
    -e Libraries/Connect/Internal/Generated\/ \
    -e Tests/ConnectLibraryTests/proto/grpc\/ \
    -e Tests/ConnectLibraryTests/Generated\/

.PHONY: buildpackage
buildpackage: ## Build all targets in the Swift package
	swift build

.PHONY: buildplugins
buildplugins: ## Build all plugin binaries
	mkdir -p $(BIN)
	swift build -c release --product protoc-gen-connect-swift
	mv ./.build/release/protoc-gen-connect-swift $(BIN)
	swift build -c release --product protoc-gen-connect-swift-mocks
	mv ./.build/release/protoc-gen-connect-swift-mocks $(BIN)
	@echo "Success! Plugins are available in $(BIN)"

.PHONY: clean
clean: cleangenerated ## Delete all plugins and generated outputs
	rm -rf $(BIN)

.PHONY: cleangenerated
cleangenerated: ## Delete all generated outputs
	rm -rf ./Examples/ElizaSharedSources/GeneratedSources/*
	rm -rf ./Libraries/Connect/Implementation/Generated/*
	rm -rf ./Tests/ConnectClientConformance/Generated/*
	rm -rf ./Tests/ConnectLibraryTests/Generated/*

.PHONY: generate
generate: cleangenerated ## Regenerate outputs for all .proto files
	cd Examples; buf generate https://github.com/connectrpc/examples-go.git#ref=$(EXAMPLES_PROTO_REF),subdir=proto
	cd Libraries/Connect; buf generate
	cd Tests/ConnectClientConformance; buf generate https://github.com/connectrpc/conformance.git#ref=$(CONFORMANCE_PROTO_REF),subdir=proto
	cd Tests/ConnectLibraryTests; buf generate https://github.com/connectrpc/conformance.git#ref=$(CONFORMANCE_PROTO_REF),subdir=proto

.PHONY: installconformancerunner
installconformancerunner: ## Install the Connect conformance test runner
	mkdir -p $(BIN)
	curl -L "https://github.com/connectrpc/conformance/releases/download/$(CONFORMANCE_RUNNER_TAG)/connectconformance-$(CONFORMANCE_RUNNER_TAG)-Darwin-arm64.tar.gz" > $(BIN)/connectconformance.tar.gz
	tar -xvzf $(BIN)/connectconformance.tar.gz -C $(BIN)

.PHONY: help
help: ## Describe useful make targets
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "%-30s %s\n", $$1, $$2}'

.PHONY: licenseheaders
licenseheaders: $(BIN)/license-headers ## Add/reformat license headers in source files
	comm -23 \
		<(git ls-files --cached --modified --others --no-empty-directory --exclude-standard | sort -u | grep -v $(LICENSE_IGNORE) ) \
		<(git ls-files --deleted | sort -u) | \
		xargs $(BIN)/license-header \
			--license-type "apache" \
			--copyright-holder "The Connect Authors" \
			--year-range "$(LICENSE_HEADER_YEAR_RANGE)"

$(BIN)/license-headers: Makefile
	mkdir -p $(@D)
	GOBIN=$(abspath $(BIN)) go install github.com/bufbuild/buf/private/pkg/licenseheader/cmd/license-header@$(LICENSE_HEADER_VERSION)

.PHONY: test
test: ## Run all tests
# test: installconformancerunner ## Run all tests
	swift build -c release --product ConnectClientConformance
	mv ./.build/release/ConnectClientConformance $(BIN)
# 	PATH="$(abspath $(BIN)):$(PATH)" connectconformance -v --conf ./Tests/ConnectClientConformance/InvocationConfigs/urlsession.yaml --known-failing ./Tests/ConnectClientConformance/InvocationConfigs/opt-outs.txt --mode client $(BIN)/ConnectClientConformance httpclient=urlsession
	PATH="$(abspath $(BIN)):$(PATH)" connectconformance -v --conf ./Tests/ConnectClientConformance/InvocationConfigs/nio.yaml --known-failing ./Tests/ConnectClientConformance/InvocationConfigs/opt-outs.txt --mode client $(BIN)/ConnectClientConformance httpclient=nio
# 	swift test
