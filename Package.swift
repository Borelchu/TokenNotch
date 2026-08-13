// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NotchUsage",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/MrKai77/DynamicNotchKit", from: "1.1.0")
    ],
    targets: [
        .executableTarget(
            name: "NotchUsage",
            dependencies: [
                .product(name: "DynamicNotchKit", package: "DynamicNotchKit")
            ],
            path: "Sources/NotchUsage",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
