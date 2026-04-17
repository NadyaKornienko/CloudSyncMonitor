//
//  MockCloudKitSyncMonitor.swift
//  CloudSyncMonitorTests
//
//  Created by Nadezhda Kornienko on 17/4/2026.
//

import Combine
import Foundation

@testable import CloudSyncMonitor

/// In-memory stub for the CloudKit sync-event port.
@MainActor
final class MockCloudKitSyncMonitor: CloudKitSyncMonitoring {

    private let statusSubject: CurrentValueSubject<CloudKitSyncStatus, Never>
    private let eventSubject = PassthroughSubject<CloudKitSyncEvent, Never>()

    private(set) var lastSetup: CloudKitSyncEvent?
    private(set) var lastImport: CloudKitSyncEvent?
    private(set) var lastExport: CloudKitSyncEvent?

    private(set) var startCallCount = 0
    private(set) var stopCallCount = 0

    init(initial: CloudKitSyncStatus = .idle) {
        self.statusSubject = CurrentValueSubject(initial)
    }

    var statusPublisher: AnyPublisher<CloudKitSyncStatus, Never> {
        statusSubject.eraseToAnyPublisher()
    }

    var eventPublisher: AnyPublisher<CloudKitSyncEvent, Never> {
        eventSubject.eraseToAnyPublisher()
    }

    var currentStatus: CloudKitSyncStatus { statusSubject.value }

    func start() { startCallCount += 1 }
    func stop() { stopCallCount += 1 }

    /// Test-only seam to push a new status through the publisher.
    func simulate(_ status: CloudKitSyncStatus) {
        statusSubject.send(status)
    }

    /// Test-only seam to push a synthetic sync event. Also updates the
    /// corresponding `lastXxx` slot for parity with the production type.
    func simulate(event: CloudKitSyncEvent) {
        switch event.type {
        case .setup: lastSetup = event
        case .import: lastImport = event
        case .export: lastExport = event
        }
        eventSubject.send(event)
    }
}
