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
# Set to use a different compiler. For example, `GO=go1.18rc1 make test`.
GO ?= go
CROSSTEST_VERSION := 4f4e96d8fea3ed9473b90a964a5ba429e7ea5649
LICENSE_HEADER_VERSION := f5dd847fb18b577a62aaf46dd168b6e5b25206a3
LICENSE_IGNORE := -e Package.swift -e $(BIN)\/ -e Generated\/ -e GeneratedMocks\/ -e Connect\/Implementation\/Generated\/ -e ConnectTests/proto/grpc\/

.PHONY: buildlibrary
buildlibrary: ## Build the Swift library targets
	swift build

.PHONY: buildplugin
buildplugin: ## Build the protoc-gen-connect-swift plugin binary
	swift build -c release --product protoc-gen-connect-swift
	mkdir -p $(BIN)
	mv ./.build/release/protoc-gen-connect-swift $(BIN)
	@echo "Success! The plugin is available in $(BIN)"

.PHONY: clean
clean: cleangenerated ## Delete all plugins and generated outputs
	rm -rf $(BIN)

.PHONY: cleangenerated
cleangenerated: ## Delete all generated outputs
	rm -rf ./Connect/Implementation/Generated/*
	rm -rf ./Generated
	rm -rf ./GeneratedMocks

.PHONY: crosstestserverstop
crosstestserverstop: ## Stop the crosstest server
	-docker container stop serverconnect servergrpc

.PHONY: crosstestserverrun
crosstestserverrun: crosstestserverstop ## Start the crosstest server
	docker run --rm --name serverconnect -p 8080:8080 -p 8081:8081 -d \
		bufbuild/connect-crosstest:$(CROSSTEST_VERSION) \
		/usr/local/bin/serverconnect --h1port "8080" --h2port "8081" --cert "cert/localhost.crt" --key "cert/localhost.key"
	docker run --rm --name servergrpc -p 8083:8083 -d \
		bufbuild/connect-crosstest:$(CROSSTEST_VERSION) \
		/usr/local/bin/servergrpc --port "8083" --cert "cert/localhost.crt" --key "cert/localhost.key"

.PHONY: generate
generate: ## Regenerate outputs for all .proto files
	cd Connect; buf generate
	cd ConnectExamples; buf generate
	cd ConnectTests; buf generate

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
			--copyright-holder "Buf Technologies, Inc." \
			--year-range "$(LICENSE_HEADER_YEAR_RANGE)"

$(BIN)/license-headers: Makefile
	mkdir -p $(@D)
	GOBIN=$(abspath $(BIN)) go install github.com/bufbuild/buf/private/pkg/licenseheader/cmd/license-header@$(LICENSE_HEADER_VERSION)

.PHONY: test
test: crosstestserverrun ## Run all tests
	swift test
	$(MAKE) crosstestserverstop
