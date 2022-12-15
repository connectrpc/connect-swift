# TODO: Replace when we switch to an official BSR plugin.
# Usage:
# buf registry login
# docker login -u $USERNAME -p $PASSWORD plugins.buf.build
# docker build -t plugins.buf.build/mrebello/connect-swift:v0.0.1-4 -f Dockerfile .
# docker push plugins.buf.build/mrebello/connect-swift:v0.0.1-4

FROM golang:alpine as build
WORKDIR /app
ADD go.mod go.sum .
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -ldflags="-s -w" -o plugin ./protoc-gen-connect-swift

FROM scratch
WORKDIR /app
COPY --from=build /app/plugin protoc-gen-connect-swift
ENTRYPOINT [ "/app/protoc-gen-connect-swift" ]
