//
//  View+CloudSyncMonitor.swift
//  CloudSyncMonitor
//
//  Created by Nadezhda Kornienko on 17/4/2026.
//

import SwiftUI

extension View {

    /// Injects a ``CloudSyncMonitor`` into the environment and, by
    /// default, starts it for the lifetime of the view hierarchy.
    ///
    /// The monitor can then be consumed downstream via:
    ///
    /// ```swift
    /// @Environment(CloudSyncMonitor.self) private var cloud
    /// ```
    ///
    /// - Parameters:
    ///   - monitor:   The aggregated monitor to inject.
    ///   - autoStart: Whether to call `start()` automatically when the
    ///     view appears. Pass `false` if you prefer to manage the
    ///     lifecycle manually (e.g. when tying it to a specific scene
    ///     phase or a login flow).
    /// - Returns: A view with the monitor installed in the environment.
    public func cloudSyncMonitor(
        _ monitor: CloudSyncMonitor,
        autoStart: Bool = true
    ) -> some View {
        modifier(
            CloudSyncMonitorModifier(monitor: monitor, autoStart: autoStart)
        )
    }
}

/// Internal modifier that performs the actual environment injection and
/// start/stop orchestration. Kept private on purpose — prefer the public
/// `cloudSyncMonitor(_:autoStart:)` entry point.
private struct CloudSyncMonitorModifier: ViewModifier {

    let monitor: CloudSyncMonitor
    let autoStart: Bool

    func body(content: Content) -> some View {
        content
            .environment(monitor)
            .task {
                // `.task` is tied to the view's lifetime; when the view
                // disappears, the task is cancelled and `stop()` runs.
                if autoStart { monitor.start() }
                // Keep the task alive for the lifetime of the view so the
                // deferred cancellation handler runs on disappear.
                for await _ in AsyncStream<Never>.makeStream().stream {}
            }
            .onDisappear {
                if autoStart { monitor.stop() }
            }
    }
}
