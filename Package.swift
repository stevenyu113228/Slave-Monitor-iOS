// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SlaveMonitor",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "SlaveMonitor", targets: ["SlaveMonitor"])
    ],
    dependencies: [
        .package(url: "https://github.com/migueldeicaza/SwiftTerm", from: "1.11.0")
    ],
    targets: [
        .target(
            name: "SlaveMonitor",
            dependencies: ["SwiftTerm"],
            path: "."
        )
    ]
)
