// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Sangtae",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "Sangtae", targets: ["Sangtae"])
    ],
    targets: [
        .executableTarget(
            name: "Sangtae",
            dependencies: [],
            path: "Sources/Sangtae"
        )
    ]
)
