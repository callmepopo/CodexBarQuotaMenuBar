// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CodexBarQuotaMenuBar",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "CodexBarQuotaMenuBar", targets: ["CodexBarQuotaWidget"])
    ],
    targets: [
        .executableTarget(
            name: "CodexBarQuotaWidget",
            path: "Sources/CodexBarQuotaWidget"
        )
    ]
)
