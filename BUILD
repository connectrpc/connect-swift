## Tools ##

load("@buildifier_prebuilt//:rules.bzl", "buildifier")
load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")
load(
    "@com_github_buildbuddy_io_rules_xcodeproj//xcodeproj:defs.bzl",
    "top_level_targets",
    "xcode_schemes",
    "xcodeproj",
)

buildifier(
    name = "buildifier.check",
    exclude_patterns = [
        "./.git/*",
        "./bazel-*",
        "./connect-crosstest/*",
    ],
    lint_mode = "warn",
    mode = "diff",
)

buildifier(
    name = "buildifier.fix",
    exclude_patterns = [
        "./.git/*",
        "./bazel-*",
        "./connect-crosstest/*",
    ],
    lint_mode = "fix",
    mode = "fix",
)

## Swift ##

swift_library(
    name = "SwiftProtobuf",
    srcs = ["@swift_protobuf//:SwiftProtobuf"],
    features = [
        "swift.emit_symbol_graph",
        "swift.enable_library_evolution",
    ],
    visibility = ["//visibility:public"],
)

xcodeproj(
    name = "xcodeproj",
    bazel_path = "bazelisk",
    build_mode = "bazel",
    project_name = "Connect",
    scheme_autogeneration_mode = "auto",  # "all" can be used to generate schemes for all deps
    schemes = [
        xcode_schemes.scheme(
            name = "Eliza App",
            launch_action = xcode_schemes.launch_action("//connect-swift/examples/eliza:app"),
        ),
        xcode_schemes.scheme(
            name = "Connect Runtime",
            build_action = xcode_schemes.build_action(["//connect-swift/src:ConnectLibrary"]),
        ),
        xcode_schemes.scheme(
            name = "SwiftProtobuf Runtime",
            build_action = xcode_schemes.build_action(["//:SwiftProtobuf"]),
        ),
        xcode_schemes.scheme(
            name = "Crosstest",
            test_action = xcode_schemes.test_action([
                "//crosstest:crosstest",
            ]),
        ),
    ],
    tags = ["manual"],
    top_level_targets = [
        # Apps / frameworks
        top_level_targets(
            labels = [
                "//connect-swift/examples/eliza:app",
                # "//connect-swift/src:ios_framework",
            ],
            target_environments = ["simulator"],
        ),
        # Tests
        "//crosstest:crosstest",
    ],
)
