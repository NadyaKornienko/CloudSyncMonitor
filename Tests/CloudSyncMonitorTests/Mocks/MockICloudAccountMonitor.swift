//
//  MockICloudAccountMonitor.swift
//  CloudSyncMonitorTests
//
//  Created by Nadezhda Kornienko on 17/4/2026.
//

import Combine

@testable import CloudSyncMonitor

/// In-memory stub that allows tests to drive the iCloud account status.
@MainActor
final class MockICloudAccountMonitor: ICloudAccountMonitoring {

    private let subject: CurrentValueSubject<ICloudAccountStatus, Never>

    private(set) var startCallCount = 0
    private(set) var stopCallCount = 0
    private(set) var refreshCallCount = 0

    init(initial: ICloudAccountStatus = .couldNotDetermine) {
        self.subject = CurrentValueSubject(initial)
    }

    var statusPublisher: AnyPublisher<ICloudAccountStatus, Never> {
        subject.eraseToAnyPublisher()
    }

    var currentStatus: ICloudAccountStatus { subject.value }

    func start() { startCallCount += 1 }
    func stop() { stopCallCount += 1 }
    func refresh() async { refreshCallCount += 1 }

    /// Test-only seam to push a new status through the publisher.
    func simulate(_ status: ICloudAccountStatus) {
        subject.send(status)
    }
}
