//
//  CloudKitSyncStatusTests.swift
//  CloudSyncMonitorTests
//
//  Created by Nadezhda Kornienko on 17/4/2026.
//

import Foundation
import Testing

@testable import CloudSyncMonitor

@Suite("CloudKitSyncStatus")
struct CloudKitSyncStatusTests {

    @Test("isSyncing is true for setup/import/export, false otherwise")
    func isSyncingFlag() {
        #expect(CloudKitSyncStatus.setup.isSyncing)
        #expect(CloudKitSyncStatus.importing.isSyncing)
        #expect(CloudKitSyncStatus.exporting.isSyncing)
        #expect(!CloudKitSyncStatus.idle.isSyncing)
        #expect(!CloudKitSyncStatus.error(message: "x").isSyncing)
    }

    @Test("hasError and errorMessage reflect .error only")
    func errorAccessors() {
        let error = CloudKitSyncStatus.error(message: "boom")
        #expect(error.hasError)
        #expect(error.errorMessage == "boom")

        #expect(!CloudKitSyncStatus.idle.hasError)
        #expect(CloudKitSyncStatus.idle.errorMessage == nil)
    }

    @Test("CloudKitSyncEvent.isInProgress depends on endDate")
    func eventProgressFlag() {
        let inProgress = CloudKitSyncEvent(
            type: .import,
            startDate: .now,
            endDate: nil,
            succeeded: false,
            errorDescription: nil
        )
        let finished = CloudKitSyncEvent(
            type: .import,
            startDate: .now,
            endDate: .now,
            succeeded: true,
            errorDescription: nil
        )
        #expect(inProgress.isInProgress)
        #expect(!finished.isInProgress)
    }
}
