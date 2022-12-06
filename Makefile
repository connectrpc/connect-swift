CROSSTEST_VERSION := 4f4e96d8fea3ed9473b90a964a5ba429e7ea5649

.PHONY: build
build:
	@echo "Building Swift plugin..."
	@go build -o protoc-gen-connect-swift cmd/protoc-gen-connect-swift/main.go

.PHONY: buildifier-check
buildifier-check:
	@bazelisk run //:buildifier.check

.PHONY: buildifier-fix
buildifier-fix:
	@bazelisk run //:buildifier.fix

.PHONY: generate
generate: clean
	buf generate

.PHONY: clean
clean:
	@rm -rf ./gen/proto

.PHONY: xcodeproj
xcodeproj:
	@bazelisk run //:xcodeproj

.PHONY: swift-example
swift-example:
	bazelisk run //connect-swift/examples/eliza:app

.PHONY: cross-test-server-stop
cross-test-server-stop:
	-docker container stop serverconnect servergrpc

.PHONY: cross-test-server-run
cross-test-server-run: cross-test-server-stop
	docker run --rm --name serverconnect -p 8080:8080 -p 8081:8081 -d \
		bufbuild/connect-crosstest:$(CROSSTEST_VERSION) \
		/usr/local/bin/serverconnect --h1port "8080" --h2port "8081" --cert "cert/localhost.crt" --key "cert/localhost.key"
	docker run --rm --name servergrpc -p 8083:8083 -d \
		bufbuild/connect-crosstest:$(CROSSTEST_VERSION) \
		/usr/local/bin/servergrpc --port "8083" --cert "cert/localhost.crt" --key "cert/localhost.key"
