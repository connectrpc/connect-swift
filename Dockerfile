# Usage (note that the BSR requires the image to be Linux amd64):
# TODO: Replace when we switch to an official BSR plugin.
#
# buf registry login
# docker login -u $USERNAME -p $PASSWORD plugins.buf.build
# docker build --platform linux/amd64 -t plugins.buf.build/mrebello/connect-swift:v0.0.1-13 -f Dockerfile .
# docker push plugins.buf.build/mrebello/connect-swift:v0.0.1-13

# The following is based on:
# https://github.com/bufbuild/remote-plugins/blob/main/swift.dockerfile

FROM swift:latest as build
WORKDIR /app
COPY . .
RUN swift build -c release --product protoc-gen-connect-swift --static-swift-stdlib

FROM swift:slim
WORKDIR /app
COPY --from=build /app/.build/release/protoc-gen-connect-swift .
ENTRYPOINT [ "/app/protoc-gen-connect-swift" ]
