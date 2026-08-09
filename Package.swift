// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.
//
// CloudSyncMonitor
// A lightweight, UI-agnostic library for observing iCloud / CloudKit
// synchronization health in SwiftUI projects backed by Core Data.
//
// Supported platforms (floor is dictated by the Observation framework):
//   - iOS       17.0+
//   - watchOS   10.0+
//   - macOS     14.0+
//   - tvOS      17.0+
//   - visionOS  1.0+

import PackageDescription

let package = Package(
    name: "CloudSyncMonitor",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v17),
        .watchOS(.v10),
        .macOS(.v14),
        .tvOS(.v17),
        .visionOS(.v1),
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
