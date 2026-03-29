import PackageDescription

let package = Package(
    name: "ChronicleCore",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
        .tvOS(.v16),
        .watchOS(.v9),
    ],
    products: [
        .library(
            name: "ChronicleCore",
            targets: ["ChronicleCore"]
        ),
    ],
    targets: [
        .target(
            name: "ChronicleCore",
            dependencies: []
        ),
        .testTarget(
            name: "ChronicleCoreTests",
            dependencies: ["ChronicleCore"]
        ),
    ]
)
