// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SpotyPopup",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "SpotyPopup",
            dependencies: [],
            path: "Sources"
        )
    ]
)
