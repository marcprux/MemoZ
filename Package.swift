// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "MemoZ",
    platforms: [
        .macOS(.v10_15), .iOS(.v13), .tvOS(.v13), .watchOS(.v7)
    ],
    products: [
        .library(name: "MemoZ", targets: ["MemoZ"]),
    ],
    targets: [
        .target(name: "MemoZ", dependencies: []),
        .testTarget(name: "MemoZTests", dependencies: ["MemoZ"]),
    ]
)
