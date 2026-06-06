//
//  SyncStatePresentationTests.swift
//  CloudSyncMonitor
//
//  Created by Nadezhda Kornienko on 22/4/2026.
//

import Foundation
import Testing

@testable import CloudSyncMonitor

@MainActor
@Suite("CloudSyncMonitor.SyncState presentation")
struct SyncStatePresentationTests {

    typealias State = CloudSyncMonitor.SyncState

    // MARK: - Helpers

    private static let online = NetworkStatus(
        isConnected: true,
        isExpensive: false,
        isConstrained: false,
        connectionType: .wifi
    )

    private static func makeDefaults() -> UserDefaults {
        let name = "CloudSyncMonitor.tests.\(UUID().uuidString)"
        let d = UserDefaults(suiteName: name)!
        d.removePersistentDomain(forName: name)
        return d
    }

    private func makeSUT(
        account: ICloudAccountStatus = .available,
        network: NetworkStatus = Self.online,
        drive: ICloudDriveStatus = .available,
        sync: CloudKitSyncStatus = .idle
    ) -> (
        sut: CloudSyncMonitor,
        account: MockICloudAccountMonitor,
        network: MockNetworkMonitor,
        drive: MockICloudDriveMonitor,
        sync: MockCloudKitSyncMonitor
    ) {
        let accountMock = MockICloudAccountMonitor(initial: account)
        let networkMock = MockNetworkMonitor(initial: network)
        let driveMock = MockICloudDriveMonitor(initial: drive)
        let syncMock = MockCloudKitSyncMonitor(initial: sync)
        let sut = CloudSyncMonitor(
            accountMonitor: accountMock,
            networkMonitor: networkMock,
            driveMonitor: driveMock,
            syncMonitor: syncMock,
            isDriveCheckEnabled: true,
            userDefaults: Self.makeDefaults()
        )
        sut.start()
        return (sut, accountMock, networkMock, driveMock, syncMock)
    }

    // MARK: - Tests

    @Test("symbolName is non-empty for every case")
    func symbolNamesAreNonEmpty() {
        let states: [State] = [
            .ok(lastSync: nil), .ok(lastSync: Date()), .initialSync,
            .syncing(.setup), .syncing(.importing), .syncing(.exporting),
            .offline,
            .signedOut(.noAccount), .signedOut(.restricted),
            .signedOut(.temporarilyUnavailable), .signedOut(.couldNotDetermine),
            .driveDisabled, .notSyncing, .failed,
        ]
        for s in states {
            #expect(!s.symbolName.isEmpty, "Empty symbol for \(s)")
        }
    }

    @Test(".ok carries lastSyncDate from the most recent successful event")
    func okCarriesLastSync() async {
        let (sut, _, _, _, sync) = makeSUT()
        let end = Date()
        sync.simulate(
            event: CloudKitSyncEvent(
                type: .import,
                startDate: end.addingTimeInterval(-1),
                endDate: end,
                succeeded: true,
                errorDescription: nil
            )
        )
        await waitUntil { sut.lastSyncDate != nil }
        #expect(sut.state == State.ok(lastSync: end))
    }

    @Test(
        "localizedMessage is empty for .ok(lastSync: nil) and non-empty otherwise"
    )
    func localizedMessagesArePresent() {
        #expect(State.ok(lastSync: nil).localizedMessage.isEmpty)
        #expect(!State.ok(lastSync: Date()).localizedMessage.isEmpty)

        let nonOk: [State] = [
            .initialSync,
            .syncing(.setup), .syncing(.importing), .syncing(.exporting),
            .offline,
            .signedOut(.noAccount), .signedOut(.restricted),
            .signedOut(.temporarilyUnavailable), .signedOut(.couldNotDetermine),
            .driveDisabled, .notSyncing, .failed,
        ]
        for s in nonOk {
            #expect(!s.localizedMessage.isEmpty, "Empty message for \(s)")
        }
    }

    @Test("signedOut(.noAccount) and signedOut(.restricted) use different copy")
    func signedOutBranchesDiffer() {
        let noAcc = State.signedOut(.noAccount).localizedMessage
        let restricted = State.signedOut(.restricted).localizedMessage
        #expect(noAcc != restricted)
    }

    @Test("failed state does NOT embed technical error in localizedMessage")
    func failedMessageDoesNotEmbedUnderlyingError() {
        let msg = State.failed.localizedMessage
        #expect(
            !msg.contains("Disk quota exceeded"),
            "localizedMessage should be generic and not contain raw error text"
        )
        #expect(
            msg.contains("iCloud"),
            "localizedMessage should mention iCloud for clarity"
        )
    }
}
