"""
Macro for easily defining Swift unit test targets.
"""

load("@build_bazel_rules_apple//apple:ios.bzl", "ios_unit_test")
load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")
load("//bazel:config.bzl", "MINIMUM_IOS_VERSION")

def connect_swift_test(name, srcs, deps = []):
    test_lib_name = name + "_lib"
    swift_library(
        name = test_lib_name,
        srcs = srcs,
        deps = deps,
        testonly = True,
        visibility = ["//visibility:private"],
    )

    ios_unit_test(
        name = name,
        deps = [test_lib_name],
        minimum_os_version = MINIMUM_IOS_VERSION,
    )
