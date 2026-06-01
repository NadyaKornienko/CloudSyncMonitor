//
//  SyncStateClassificationTests.swift
//  CloudSyncMonitor
//
//  Created by Nadezhda Kornienko on 22/4/2026.
//

import Foundation
import Testing

@testable import CloudSyncMonitor

@MainActor
@Suite("CloudSyncMonitor.SyncState classification")
struct SyncStateClassificationTests {

    typealias State = CloudSyncMonitor.SyncState
    typealias Severity = CloudSyncMonitor.SyncState.Severity
    typealias Category = CloudSyncMonitor.SyncState.Category

    // MARK: - Severity Tests

    @Test("severity mapping covers every case")
    func severityMapping() {
        let infoStates: [State] = [
            .ok(lastSync: nil), .ok(lastSync: Date()), .initialSync,
            .syncing(.setup), .syncing(.importing), .syncing(.exporting),
            .offline,
        ]
        for state in infoStates {
            #expect(state.severity == .info, "❌ \(state) should be .info")
        }

        let warningStates: [State] = [
            .signedOut(.noAccount), .signedOut(.restricted),
            .signedOut(.temporarilyUnavailable), .signedOut(.couldNotDetermine),
            .driveDisabled,
        ]
        for state in warningStates {
            #expect(state.severity == .warning, "❌ \(state) should be .warning")
        }

        let criticalStates: [State] = [
            .notSyncing, .failed(message: "error"),
        ]
        for state in criticalStates {
            #expect(
                state.severity == .critical,
                "❌ \(state) should be .critical"
            )
        }
    }

    // MARK: - Category Tests

    @Test("category mapping covers every case")
    func categoryMapping() {
        let noneStates: [State] = [
            .ok(lastSync: nil), .ok(lastSync: Date()),
        ]
        for state in noneStates {
            #expect(state.category == .none, "❌ \(state) should be .none")
        }

        let progressStates: [State] = [
            .initialSync, .syncing(.setup), .syncing(.importing),
            .syncing(.exporting),
        ]
        for state in progressStates {
            #expect(
                state.category == .progress,
                "❌ \(state) should be .progress"
            )
        }

        #expect(
            State.offline.category == .network,
            "❌ offline should be .network"
        )

        let accountStates: [State] = [
            .signedOut(.noAccount), .signedOut(.restricted),
            .signedOut(.temporarilyUnavailable), .signedOut(.couldNotDetermine),
        ]
        for state in accountStates {
            #expect(state.category == .account, "❌ \(state) should be .account")
        }

        #expect(
            State.driveDisabled.category == .drive,
            "❌ driveDisabled should be .drive"
        )

        let syncStates: [State] = [
            .notSyncing, .failed(message: "error"),
        ]
        for state in syncStates {
            #expect(state.category == .sync, "❌ \(state) should be .sync")
        }
    }

    // MARK: - Boolean Flag Tests

    @Test("isProgress reflects .progress category")
    func isProgressFlag() {
        let progressStates: [State] = [
            .initialSync, .syncing(.setup), .syncing(.importing),
            .syncing(.exporting),
        ]
        for state in progressStates {
            #expect(state.isProgress, "❌ \(state) should be progress")
        }

        let nonProgressStates: [State] = [
            .ok(lastSync: nil), .ok(lastSync: Date()), .offline,
            .signedOut(.noAccount), .signedOut(.restricted),
            .signedOut(.temporarilyUnavailable), .signedOut(.couldNotDetermine),
            .driveDisabled, .notSyncing, .failed(message: "error"),
        ]
        for state in nonProgressStates {
            #expect(!state.isProgress, "❌ \(state) should NOT be progress")
        }
    }

    @Test("isProblem is true iff severity != .info")
    func isProblemFlag() {
        let nonProblems: [State] = [
            .ok(lastSync: nil), .ok(lastSync: Date()), .initialSync,
            .syncing(.setup), .syncing(.importing), .syncing(.exporting),
            .offline,
        ]
        for state in nonProblems {
            #expect(!state.isProblem, "❌ \(state) should NOT be a problem")
        }

        let problems: [State] = [
            .signedOut(.noAccount), .signedOut(.restricted),
            .signedOut(.temporarilyUnavailable), .signedOut(.couldNotDetermine),
            .driveDisabled, .notSyncing, .failed(message: "error"),
        ]
        for state in problems {
            #expect(state.isProblem, "❌ \(state) should be a problem")
        }
    }

    // MARK: - Enum Properties Tests

    @Test("Category.allCases enumerates every case exactly once")
    func categoryAllCases() {
        let expected: Set<Category> = [
            .none, .progress, .network, .account, .drive, .sync,
        ]
        let actual = Set(Category.allCases)

        #expect(actual == expected, "❌ Expected \(expected), got \(actual)")
        #expect(
            Category.allCases.count == 6,
            "❌ Expected 6 categories, got \(Category.allCases.count)"
        )
    }

    @Test("Severity is ordered info < warning < critical")
    func severityOrdering() {
        #expect(Severity.info < .warning)
        #expect(Severity.warning < .critical)
        #expect(Severity.info < .critical)

        #expect(Severity.critical > .warning)
        #expect(Severity.warning > .info)

        #expect(Severity.info == .info)
        #expect(Severity.warning == .warning)
        #expect(Severity.critical == .critical)
    }

    // MARK: - UI Presentation Tests

    @Test("symbolName maps correctly for every case")
    func symbolNames() {
        #expect(State.ok(lastSync: nil).symbolName == "checkmark.icloud")
        #expect(State.initialSync.symbolName == "icloud.and.arrow.down")
        #expect(State.syncing(.setup).symbolName == "icloud")
        #expect(State.syncing(.importing).symbolName == "icloud.and.arrow.down")
        #expect(State.syncing(.exporting).symbolName == "icloud.and.arrow.up")
        #expect(State.offline.symbolName == "bolt.horizontal.icloud")
        #expect(
            State.signedOut(.noAccount).symbolName
                == "person.crop.circle.badge.exclamationmark"
        )
        #expect(State.driveDisabled.symbolName == "xmark.icloud")
        #expect(State.notSyncing.symbolName == "exclamationmark.icloud")
        #expect(
            State.failed(message: "x").symbolName
                == "exclamationmark.icloud.fill"
        )
    }

    @Test("symbolColor maps to severity")
    func symbolColors() {
        #expect(State.ok(lastSync: nil).symbolColor == .secondary)
        #expect(State.initialSync.symbolColor == .secondary)
        #expect(State.offline.symbolColor == .secondary)

        #expect(State.signedOut(.noAccount).symbolColor == .orange)
        #expect(State.driveDisabled.symbolColor == .orange)

        #expect(State.notSyncing.symbolColor == .red)
        #expect(State.failed(message: "x").symbolColor == .red)
    }
}
