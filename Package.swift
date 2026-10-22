// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CubeControl",
    defaultLocalization: "es",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
    ],
    products: [
        .executable(
            name: "CubeControl",
            targets: ["CubeControl"]
        )
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "CubeControl",
            dependencies: [],
            path: "Sources/CubeControl",
            resources: [
                .process("../../Resources")
            ],
            linkerSettings: [
                .linkedFramework("CoreMIDI"),
                .linkedFramework("AVFoundation")
            ]
        )
    ]
)
