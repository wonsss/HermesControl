// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "HermesControl",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "HermesControl",
            path: "Sources/HermesControl"
        ),
        .testTarget(
            name: "HermesControlTests",
            dependencies: ["HermesControl"],
            path: "Tests/HermesControlTests"
        ),
    ]
)
