//
//  MockNetworkMonitor.swift
//  CloudSyncMonitorTests
//
//  Created by Nadezhda Kornienko on 17/4/2026.
//

import Combine
import Foundation

@testable import CloudSyncMonitor

/// In-memory stub for the reachability port.
final class MockNetworkMonitor: NetworkMonitoring, @unchecked Sendable {

    private let subject: CurrentValueSubject<NetworkStatus, Never>
    private let lock = NSLock()

    private(set) var startCallCount = 0
    private(set) var stopCallCount = 0

    init(initial: NetworkStatus = .disconnected) {
        self.subject = CurrentValueSubject(initial)
    }

    var statusPublisher: AnyPublisher<NetworkStatus, Never> {
        subject.eraseToAnyPublisher()
    }

    var currentStatus: NetworkStatus { subject.value }

    func start() {
        lock.lock()
        defer { lock.unlock() }
        startCallCount += 1
    }

    func stop() {
        lock.lock()
        defer { lock.unlock() }
        stopCallCount += 1
    }

    /// Test-only seam to push a new status through the publisher.
    func simulate(_ status: NetworkStatus) {
        subject.send(status)
    }
}
