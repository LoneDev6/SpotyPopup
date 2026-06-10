// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SpotifydUI",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "SpotifydUI",
            dependencies: [],
            path: "Sources"
        )
    ]
)
