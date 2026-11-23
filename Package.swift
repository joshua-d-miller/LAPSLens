// swift-tools-version:6.0
// Copyright (c) 2026 Joshua D. Miller. MIT License.
// LAPSCore: the platform-independent core of LAPS for macOS 3.0
// (format decoders, Windows time helpers, phonetic readout).
// Kept free of AppKit/SwiftUI and networking so it builds and tests
// on Linux CI as well as macOS.
import PackageDescription

let package = Package(
    name: "LAPSCore",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "LAPSCore", targets: ["LAPSCore"])
    ],
    targets: [
        .target(name: "LAPSCore"),
        .testTarget(name: "LAPSCoreTests", dependencies: ["LAPSCore"])
    ],
    swiftLanguageModes: [.v6]
)
