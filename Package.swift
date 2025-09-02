// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "CoreTimer",
    platforms: [
        .macOS(.v14),
        .iOS(.v16),
        .watchOS(.v6)
    ],
    products: [
        .library(name: "CoreTimer", targets: ["CoreTimer"]),
    ],
    targets: [
        .target(name: "CoreTimer"),
        .testTarget(name: "CoreTimerTests", dependencies: ["CoreTimer"]),
    ]
)
