// swift-tools-version: 5.10
//
// SPM target for the pure-logic Shared module. Compiles without Xcode (CLT-only).
// Tests live under `Tests/` as XCTest files; they require full Xcode to run
// because the Command Line Tools toolchain does NOT ship XCTest or Swift Testing.
//
// Build: `swift build`
// Run tests: open the project in Xcode (after `xcodegen generate`) and ⌘U,
// or `xcodebuild test -scheme BreezeFan -destination 'platform=macOS'`.

import PackageDescription

let package = Package(
    name: "FanControlCore",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "FanControlShared", targets: ["FanControlShared"]),
    ],
    targets: [
        .target(
            name: "FanControlShared",
            path: "Shared",
            exclude: [
                "HelperProtocol.swift" // requires NSXPCInterface bridging
            ]
        ),
    ]
)
