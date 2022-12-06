load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

## Tools ##

http_archive(
    name = "buildifier_prebuilt",
    sha256 = "ecef8f8c39eaf4f1c1604c677d232ade33818f898e35e7826e7564a648751350",
    strip_prefix = "buildifier-prebuilt-5.1.0.2",
    urls = [
        "http://github.com/keith/buildifier-prebuilt/archive/5.1.0.2.tar.gz",
    ],
)

load("@buildifier_prebuilt//:deps.bzl", "buildifier_prebuilt_deps")

buildifier_prebuilt_deps()

load("@bazel_skylib//:workspace.bzl", "bazel_skylib_workspace")

bazel_skylib_workspace()

load("@buildifier_prebuilt//:defs.bzl", "buildifier_prebuilt_register_toolchains")

buildifier_prebuilt_register_toolchains()

## Swift ##

http_archive(
    name = "build_bazel_rules_apple",
    sha256 = "687644bf48ccf91286f31c4ec26cf6591800b39bee8a630438626fc9bb4042de",
    strip_prefix = "rules_apple-a0f8748ce89698a599149d984999eaefd834c004",
    url = "https://github.com/bazelbuild/rules_apple/archive/a0f8748ce89698a599149d984999eaefd834c004.tar.gz",
)

load("@build_bazel_rules_apple//apple:repositories.bzl", "apple_rules_dependencies")

apple_rules_dependencies(ignore_version_differences = True)

http_archive(
    name = "build_bazel_rules_swift",
    sha256 = "422558831da7719658ab0ffb3c994d92ddc6541e3610a751613a324bb5d10ffe",
    strip_prefix = "rules_swift-e769f8d6a4adae93c244f244480a3ae740f24384",
    url = "https://github.com/bazelbuild/rules_swift/archive/e769f8d6a4adae93c244f244480a3ae740f24384.tar.gz",
)

load("@build_bazel_rules_swift//swift:repositories.bzl", "swift_rules_dependencies")

swift_rules_dependencies()

http_archive(
    name = "com_github_buildbuddy_io_rules_xcodeproj",
    sha256 = "564381b33261ba29e3c8f505de82fc398452700b605d785ce3e4b9dd6c73b623",
    url = "https://github.com/buildbuddy-io/rules_xcodeproj/releases/download/0.9.0/release.tar.gz",
)

load("@com_github_buildbuddy_io_rules_xcodeproj//xcodeproj:repositories.bzl", "xcodeproj_rules_dependencies")

xcodeproj_rules_dependencies()

http_archive(
    name = "wire_swift",
    build_file = "@//:bazel/WireSwift.BUILD",
    sha256 = "15c927359fdf77d2a2aa518794d3c4b4d94219f1b3212c43bfc1e8258d69384b",
    strip_prefix = "wire-e26d6588ae230e480ba2f077cd2f4dc78f5bd5fe",
    url = "https://github.com/square/wire/archive/e26d6588ae230e480ba2f077cd2f4dc78f5bd5fe.zip",
)
