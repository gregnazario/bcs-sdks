// swift-tools-version:5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "BCS",
    platforms: [
        .macOS(.v12),
        .iOS(.v15),
        .tvOS(.v15),
        .watchOS(.v8)
    ],
    products: [
        .library(
            name: "BCS",
            targets: ["BCS"]
        )
    ],
    targets: [
        .target(
            name: "BCS",
            dependencies: [],
            path: "Sources/BCS"
        ),
        .testTarget(
            name: "BCSTests",
            dependencies: ["BCS"],
            path: "Tests/BCSTests"
        )
    ]
)
