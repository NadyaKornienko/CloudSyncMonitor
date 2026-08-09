//
//  CloudKitSyncMonitorTests.swift
//  CloudSyncMonitorTests
//
//  Created by Nadezhda Kornienko on 9/8/2026.
//

import Foundation
import Testing

@testable import CloudSyncMonitor

@MainActor
@Suite("CloudKitSyncMonitor status derivation")
struct CloudKitSyncMonitorTests {

    private func event(
        _ type: CloudKitSyncEvent.EventType,
        inProgress: Bool = false,
        succeeded: Bool = true,
        errorDescription: String? = nil
    ) -> CloudKitSyncEvent {
        CloudKitSyncEvent(
            type: type,
            startDate: .now,
            endDate: inProgress ? nil : .now,
            succeeded: succeeded,
            errorDescription: errorDescription
        )
    }

    @Test("An in-progress event reports its own phase")
    func inProgressEventReportsPhase() {
        #expect(
            CloudKitSyncMonitor.status(
                after: event(.import, inProgress: true),
                inProgress: [.import]
            ) == .importing
        )
        #expect(
            CloudKitSyncMonitor.status(
                after: event(.export, inProgress: true),
                inProgress: [.export]
            ) == .exporting
        )
        #expect(
            CloudKitSyncMonitor.status(
                after: event(.setup, inProgress: true),
                inProgress: [.setup]
            ) == .setup
        )
    }

    @Test("A finished export does not report .idle while an import runs")
    func overlappingPhasesDoNotFlipToIdle() {
        #expect(
            CloudKitSyncMonitor.status(
                after: event(.export),
                inProgress: [.import]
            ) == .importing
        )
    }

    @Test("Setup outranks import and export while several phases run")
    func phasePriority() {
        #expect(
            CloudKitSyncMonitor.status(
                after: event(.export, inProgress: true),
                inProgress: [.setup, .import, .export]
            ) == .setup
        )
        #expect(
            CloudKitSyncMonitor.status(
                after: event(.export, inProgress: true),
                inProgress: [.import, .export]
            ) == .importing
        )
    }

    @Test("The last finished event yields .idle when nothing is in flight")
    func idleWhenNothingRuns() {
        #expect(
            CloudKitSyncMonitor.status(
                after: event(.import),
                inProgress: []
            ) == .idle
        )
    }

    @Test("A failed event surfaces as .error even without a message")
    func failureWithoutMessageIsStillAnError() {
        let status = CloudKitSyncMonitor.status(
            after: event(.import, succeeded: false),
            inProgress: []
        )
        #expect(status == .error(message: ""))
        #expect(status.hasError)
    }

    @Test("A failed event carries its error description")
    func failureCarriesMessage() {
        let status = CloudKitSyncMonitor.status(
            after: event(.export, succeeded: false, errorDescription: "quota"),
            inProgress: [.import]
        )
        #expect(status == .error(message: "quota"))
    }
}
