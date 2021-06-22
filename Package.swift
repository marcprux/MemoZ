// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "MemoZ",
    products: [
        .library(
            name: "MemoZ",
            targets: ["MemoZ"]),
    ],
    targets: [
        .target(
            name: "MemoZ",
            dependencies: []),
        .testTarget(
            name: "MemoZTests",
            dependencies: ["MemoZ"]),
    ]
)
