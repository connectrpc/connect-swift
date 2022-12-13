FROM golang:alpine as build
WORKDIR /app
ADD go.mod go.sum .
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -ldflags="-s -w" -o ./protoc-gen-connect-swift/protoc-gen-connect-swift ./protoc-gen-connect-swift

FROM scratch
WORKDIR /app
COPY --from=build /app/protoc-gen-connect-swift/protoc-gen-connect-swift .
ENTRYPOINT [ "/app/protoc-gen-connect-swift/protoc-gen-connect-swift" ]
