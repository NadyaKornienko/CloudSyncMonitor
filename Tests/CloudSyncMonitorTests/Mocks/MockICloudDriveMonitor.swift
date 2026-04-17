//
//  MockICloudDriveMonitor.swift
//  CloudSyncMonitorTests
//
//  Created by Nadezhda Kornienko on 17/4/2026.
//

import Combine

@testable import CloudSyncMonitor

/// In-memory stub for the iCloud Drive availability port.
@MainActor
final class MockICloudDriveMonitor: ICloudDriveMonitoring {

    private let subject: CurrentValueSubject<ICloudDriveStatus, Never>

    private(set) var startCallCount = 0
    private(set) var stopCallCount = 0

    init(initial: ICloudDriveStatus = .unavailable) {
        self.subject = CurrentValueSubject(initial)
    }

    var statusPublisher: AnyPublisher<ICloudDriveStatus, Never> {
        subject.eraseToAnyPublisher()
    }

    var currentStatus: ICloudDriveStatus { subject.value }

    func start() { startCallCount += 1 }
    func stop() { stopCallCount += 1 }

    /// Test-only seam to push a new status through the publisher.
    func simulate(_ status: ICloudDriveStatus) {
        subject.send(status)
    }
}
