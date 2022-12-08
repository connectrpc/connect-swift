# load("@build_bazel_rules_apple//apple:ios.bzl", "ios_static_framework")
load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "ConnectLibrary",
    srcs = glob(["**/*.swift"]),
    features = [
        "swift.emit_symbol_graph",
        "swift.enable_library_evolution",
    ],
    module_name = "Connect",
    visibility = ["//visibility:public"],
    deps = ["//:SwiftProtobuf"],
)

# TODO: Build and distribute iOS Connect framework
# ios_static_framework(
#     name = "ios_framework",
#     bundle_name = "Connect",
#     minimum_os_version = MINIMUM_IOS_VERSION,
#     visibility = ["//visibility:public"],
#     deps = ["ConnectLibrary"],
# )
