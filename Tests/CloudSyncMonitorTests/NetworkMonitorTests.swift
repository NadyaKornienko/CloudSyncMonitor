//
//  NetworkMonitorTests.swift
//  CloudSyncMonitorTests
//
//  Created by Nadezhda Kornienko on 9/8/2026.
//

import Combine
import Foundation
import Testing

@testable import CloudSyncMonitor

/// Thread-safe counter: `NWPathMonitor` delivers path updates on a
/// background queue while the test asserts on the main actor.
private final class SendCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0

    func increment() {
        lock.lock()
        defer { lock.unlock() }
        value += 1
    }

    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return value
    }
}

@MainActor
@Suite("NetworkMonitor")
struct NetworkMonitorTests {

    @Test("start() after stop() resumes path updates")
    func restartDeliversUpdates() async {
        let monitor = NetworkMonitor()
        let counter = SendCounter()
        var cancellables = Set<AnyCancellable>()

        monitor.statusPublisher
            .sink { @Sendable _ in counter.increment() }
            .store(in: &cancellables)

        // CurrentValueSubject replays its current value on subscription.
        #expect(counter.count == 1)

        // NWPathMonitor always delivers the current path shortly after start.
        monitor.start()
        await waitUntil { counter.count >= 2 }

        monitor.stop()
        let countAfterStop = counter.count

        monitor.start()
        await waitUntil { counter.count > countAfterStop }
        monitor.stop()
    }

    @Test("start() is idempotent while already running")
    func startIsIdempotent() async {
        let monitor = NetworkMonitor()
        let counter = SendCounter()
        var cancellables = Set<AnyCancellable>()

        monitor.statusPublisher
            .sink { @Sendable _ in counter.increment() }
            .store(in: &cancellables)

        monitor.start()
        await waitUntil { counter.count >= 2 }
        let countAfterFirstStart = counter.count

        // A second start() must not spin up another NWPathMonitor
        // (which would re-deliver the current path).
        monitor.start()
        try? await Task.sleep(for: .milliseconds(100))
        #expect(counter.count == countAfterFirstStart)

        monitor.stop()
    }
}
