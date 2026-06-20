// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Automations",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "Automations",
            path: "Sources/Automations"
        )
    ]
)
