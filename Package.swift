// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ClaudeRemote",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "ClaudeRemote", targets: ["ClaudeRemote"])
    ],
    dependencies: [
        .package(url: "https://github.com/migueldeicaza/SwiftTerm", from: "1.11.0")
    ],
    targets: [
        .target(
            name: "ClaudeRemote",
            dependencies: ["SwiftTerm"],
            path: "."
        )
    ]
)
