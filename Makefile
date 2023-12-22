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
CONFORMANCE_VERSION := 0d0d9b5556613468d5120c0da14570ebcf4a5f3b
EXAMPLES_VERSION := e74547031f662f81a62f5e95ebaa9f7037e0c41b
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
	rm -rf ./Tests/ConnectLibraryTests/Generated/*

.PHONY: conformanceserverstop
conformanceserverstop: ## Stop the conformance server
	-docker container stop serverconnect servergrpc

.PHONY: conformanceserverrun
conformanceserverrun: conformanceserverstop ## Start the conformance server
	docker run --rm --name serverconnect -p 8080:8080 -p 8081:8081 -d \
		connectrpc/conformance:$(CONFORMANCE_VERSION) \
		/usr/local/bin/serverconnect --h1port "8080" --h2port "8081" --cert "cert/localhost.crt" --key "cert/localhost.key"
	docker run --rm --name servergrpc -p 8083:8083 -d \
		connectrpc/conformance:$(CONFORMANCE_VERSION) \
		/usr/local/bin/servergrpc --port "8083" --cert "cert/localhost.crt" --key "cert/localhost.key"

.PHONY: generate
generate: cleangenerated ## Regenerate outputs for all .proto files
	cd Examples; buf generate https://github.com/connectrpc/examples-go.git#ref=$(EXAMPLES_VERSION),subdir=proto
	cd Libraries/Connect; buf generate
	cd Tests/ConnectLibraryTests; buf generate https://github.com/connectrpc/conformance.git#ref=$(CONFORMANCE_VERSION),subdir=proto

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

.PHONY: testios
testios: conformanceserverrun ## Run iOS tests
	set -o pipefail && xcodebuild -scheme Connect-Package -destination 'platform=iOS Simulator,name=iPhone 15,OS=17.2' test | xcbeautify
	$(MAKE) conformanceserverstop

.PHONY: testmacos
testmacos: conformanceserverrun ## Run macOS tests
	set -o pipefail && xcodebuild -scheme Connect-Package -destination 'platform=macOS' test | xcbeautify
	$(MAKE) conformanceserverstop

.PHONY: testtvos
testtvos: conformanceserverrun ## Run tvOS tests
	set -o pipefail && xcodebuild -scheme Connect-Package -destination 'platform=tvOS Simulator,name=Apple TV,OS=17.2' test | xcbeautify
	$(MAKE) conformanceserverstop

.PHONY: testwatchos
testwatchos: conformanceserverrun ## Run watchOS tests
	set -o pipefail && xcodebuild -scheme Connect-Package -destination 'platform=watchOS Simulator,name=Apple Watch Series 9 (45mm),OS=10.2' test | xcbeautify
	$(MAKE) conformanceserverstop
