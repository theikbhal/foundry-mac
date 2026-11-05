// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Foundry",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Foundry",
            path: "Sources/Foundry",
            linkerSettings: [
                .linkedLibrary("sqlite3")
            ]
        )
    ],
    swiftLanguageModes: [.v5]
)
