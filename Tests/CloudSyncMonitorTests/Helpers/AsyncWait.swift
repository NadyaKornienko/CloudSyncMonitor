//
//  AsyncWait.swift
//  CloudSyncMonitorTests
//
//  Created by Nadezhda Kornienko on 17/4/2026.
//

//
//  Polls a condition until it becomes true or a timeout elapses.
//  Needed because the façade dispatches publisher values to the main
//  queue asynchronously, so state mutations become visible on the
//  next run-loop tick rather than synchronously.
//

import Foundation
import Testing

/// Waits until `condition` returns `true` or the timeout elapses.
///
/// - Parameters:
///   - timeout:   Maximum wait duration. Defaults to 1 second.
///   - interval:  Polling interval. Defaults to 10 ms.
///   - condition: A main-actor-isolated predicate evaluated on every poll.
/// - Throws: Fails the current test via `Issue.record` if the condition
///           does not hold in time.
@MainActor
func waitUntil(
    timeout: Duration = .seconds(1),
    interval: Duration = .milliseconds(10),
    _ condition: @MainActor () -> Bool,
    sourceLocation: SourceLocation = #_sourceLocation
) async {
    let clock = ContinuousClock()
    let start = clock.now
    while !condition() {
        if clock.now - start > timeout {
            Issue.record(
                "Timed out after \(timeout) waiting for condition.",
                sourceLocation: sourceLocation
            )
            return
        }
        try? await Task.sleep(for: interval)
    }
}
