CROSSTEST_VERSION := 4f4e96d8fea3ed9473b90a964a5ba429e7ea5649

.PHONY: build-connect-plugin
build-connect-plugin:
	@echo "Building connect-swift plugin..."
	@go build -o ./protoc-gen-connect-swift/plugin ./protoc-gen-connect-swift/main.go

.PHONY: build-connect
build-connect:
	@echo "Building Connect library..."
	@swift build

.PHONY: generate
generate: clean
	buf generate

.PHONY: clean
clean:
	@rm -rf ./gen/proto

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
