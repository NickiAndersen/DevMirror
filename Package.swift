// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DevMirror",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "DevMirror", targets: ["DevMirror"]),
        .library(name: "MirrorCore", targets: ["MirrorCore"]),
    ],
    targets: [
        .target(name: "MirrorCore"),
        .executableTarget(
            name: "DevMirror",
            dependencies: ["MirrorCore"]
        ),
        .testTarget(
            name: "MirrorCoreTests",
            dependencies: ["MirrorCore"]
        ),
    ]
)
