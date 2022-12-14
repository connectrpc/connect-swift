load("@build_bazel_rules_apple//apple:ios.bzl", "ios_application")
load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "app_lib",
    srcs = glob(["*.swift"]),
    visibility = ["//visibility:private"],
    deps = [
        "//:SwiftProtobuf",
        "//connect-swift/src:ConnectLibrary",
        "//gen:SwiftGenerated",
    ],
)

ios_application(
    name = "app",
    bundle_id = "build.buf.eliza-example",
    families = ["iphone"],
    infoplists = ["Info.plist"],
    # iOS 15 is used to take advantage of new SwiftUI APIs.
    minimum_os_version = "15.0",
    sdk_frameworks = ["UIKit"],
    visibility = ["//visibility:public"],
    deps = ["app_lib"],
)
