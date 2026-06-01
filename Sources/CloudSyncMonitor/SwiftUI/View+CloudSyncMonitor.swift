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
    /// @Environment(CloudSyncMonitor.self) private var syncMonitor
    /// ```
    ///
    /// - Parameters:
    ///   - monitor:   The aggregated monitor to inject.
    ///   - autoStart: Whether to call `start()` automatically when the
    ///     view appears and `stop()` when it disappears. Pass `false` if
    ///     you prefer to manage the lifecycle manually (e.g. when tying
    ///     it to a specific scene phase or a login flow).
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

/// Internal modifier that performs environment injection and start/stop
/// orchestration. Kept private on purpose — prefer the public
/// `cloudSyncMonitor(_:autoStart:)` entry point.
///
/// ## Lifecycle
///
/// `start()` and `stop()` on ``CloudSyncMonitor`` are synchronous and
/// idempotent, so plain `.onAppear` / `.onDisappear` is the idiomatic
/// way to bind them to a view's lifetime. We deliberately avoid `.task`
/// here: it would either complete immediately (because `start()` is
/// synchronous) or require an artificial "keep-alive" loop, both of
/// which obscure intent without buying anything.
private struct CloudSyncMonitorModifier: ViewModifier {

    let monitor: CloudSyncMonitor
    let autoStart: Bool

    func body(content: Content) -> some View {
        content
            .environment(monitor)
            .onAppear {
                if autoStart { monitor.start() }
            }
            .onDisappear {
                if autoStart { monitor.stop() }
            }
    }
}
