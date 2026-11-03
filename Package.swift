// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Kalaminum",
    platforms: [.macOS(.v14)],
    targets: [
        // Pure logic (slots, storage, summaries) — no AppKit, fully unit-tested.
        .target(name: "KalaminumCore"),
        // The menu bar app itself.
        .executableTarget(name: "Kalaminum", dependencies: ["KalaminumCore"]),
        .testTarget(name: "KalaminumCoreTests", dependencies: ["KalaminumCore"]),
    ],
    swiftLanguageModes: [.v5]
)
