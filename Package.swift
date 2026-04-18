// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.
//
// CloudSyncMonitor
// A lightweight, UI-agnostic library for observing iCloud / CloudKit
// synchronization health in SwiftUI projects backed by Core Data.
//
// Supported platforms:
//   - iOS       17.4+
//   - watchOS   11.5+
//   - macOS     14.4+
//   - tvOS      17.4+
//   - visionOS  1.1+

import PackageDescription

let package = Package(
    name: "CloudSyncMonitor",
    platforms: [
        .iOS("17.4"),
        .watchOS("11.5"),
        .macOS("14.4"),
        .tvOS("17.4"),
        .visionOS("1.1"),
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "CloudSyncMonitor",
            targets: ["CloudSyncMonitor"]
        )
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "CloudSyncMonitor",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "CloudSyncMonitorTests",
            dependencies: ["CloudSyncMonitor"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
