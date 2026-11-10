// swift-tools-version: 5.9
import PackageDescription

// No test target: Command Line Tools ship neither XCTest nor Swift Testing.
// `Scrubby --selftest` covers the key filter and the critter art instead.
let package = Package(
    name: "Scrubby",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "Scrubby", path: "Sources/Scrubby"),
    ]
)
