// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "Shpping",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "Shpping", path: "Sources/Shpping")
    ]
)
