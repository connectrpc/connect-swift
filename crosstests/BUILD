load("//bazel:swift_test.bzl", "connect_swift_test")

connect_swift_test(
    name = "crosstests",
    srcs = glob(["*.swift"]),
    visibility = ["//visibility:public"],
    deps = [
        "//:SwiftProtobuf",
        "//connect-swift/src:ConnectLibrary",
        "//gen:SwiftGenerated",
    ],
)
