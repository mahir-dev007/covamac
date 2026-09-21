// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CovaMac",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "CovaMac", targets: ["CovaMac"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "CovaMac",
            dependencies: [],
            path: "Sources"
        )
    ]
)
