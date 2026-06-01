//
//  SyncStateDisplayPolicyTests.swift
//  CloudSyncMonitor
//
//  Created by Nadezhda Kornienko on 22/4/2026.
//

import Foundation
import Testing

@testable import CloudSyncMonitor

// MARK: - DisplayPolicy

@MainActor
@Suite("CloudSyncMonitor.DisplayPolicy")
struct SyncStateDisplayPolicyTests {
    
    typealias Policy = CloudSyncMonitor.DisplayPolicy
    typealias Category = CloudSyncMonitor.SyncState.Category

    @Test(".all covers every category")
    func allCoversEveryCategory() {
        #expect(Policy.all.categories == Set(Category.allCases))
    }

    @Test(".problemsOnly is exactly {account, drive, sync}")
    func problemsOnlyContents() {
        #expect(Policy.problemsOnly.categories == [.account, .drive, .sync])
    }

    @Test("Custom policy round-trips its categories")
    func customPolicyRoundTrip() {
        let p = Policy(categories: [.network, .drive])
        #expect(p.categories == [.network, .drive])
    }

    @Test("Equatable compares by categories")
    func equatableByCategories() {
        #expect(
            Policy(categories: [.account, .sync])
                == Policy(categories: [.sync, .account])
        )
        #expect(Policy.all != Policy.problemsOnly)
    }
}

// MARK: - State derivation

@MainActor
@Suite("CloudSyncMonitor.state derivation")
struct StateDerivationTests {

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
        network: NetworkStatus = StateDerivationTests.online,
        drive: ICloudDriveStatus = .available,
        sync: CloudKitSyncStatus = .idle,
        hasCompletedInitialSync: Bool = true
    ) -> CloudSyncMonitor {
        let sut = CloudSyncMonitor(
            accountMonitor: MockICloudAccountMonitor(initial: account),
            networkMonitor: MockNetworkMonitor(initial: network),
            driveMonitor: MockICloudDriveMonitor(initial: drive),
            syncMonitor: MockCloudKitSyncMonitor(initial: sync),
            isDriveCheckEnabled: true,
            userDefaults: Self.makeDefaults()
        )
        sut.hasCompletedInitialSync = hasCompletedInitialSync
        sut.start()
        return sut
    }

    // MARK: - Tests

    @Test("All green → .ok")
    func allGreenIsOk() async {
        let sut = makeSUT()
        await waitUntil { sut.state == .ok(lastSync: nil) }
        #expect(sut.state == .ok(lastSync: nil))
    }

    @Test("No network wins over every other failure (offline precedence)")
    func offlineHasHighestPrecedence() async {
        let sut = makeSUT(
            account: .noAccount,
            network: .disconnected,
            drive: .unavailable,
            sync: .error(message: "x")
        )
        await waitUntil { sut.state == .offline }
        #expect(sut.state == .offline)
    }

    @Test("No account (online) → .signedOut(reason) carrying the exact status")
    func signedOutCarriesReason() async {
        let cases: [ICloudAccountStatus] = [
            .noAccount, .restricted, .temporarilyUnavailable,
            .couldNotDetermine,
        ]
        for status in cases {
            let sut = makeSUT(account: status)
            await waitUntil { sut.state == .signedOut(status) }
            #expect(sut.state == .signedOut(status))
        }
    }

    @Test("Drive unavailable (account OK, online) → .driveDisabled")
    func driveDisabledMapsThrough() async {
        let sut = makeSUT(drive: .unavailable)
        await waitUntil { sut.state == .driveDisabled }
        #expect(sut.state == .driveDisabled)
    }

    @Test("Sync error → .failed(message) preserves the underlying text")
    func syncErrorIsFailed() async {
        let sut = makeSUT(sync: .error(message: "boom"))
        await waitUntil { sut.state == .failed(message: "boom") }
        #expect(sut.state == .failed(message: "boom"))
    }

    @Test("Each CloudKitSyncStatus phase maps to its .syncing(.phase) twin")
    func phasesMapThrough() async {
        let pairs: [(CloudKitSyncStatus, CloudSyncMonitor.SyncState)] = [
            (.setup, .syncing(.setup)),
            (.importing, .syncing(.importing)),
            (.exporting, .syncing(.exporting)),
        ]
        for (input, expected) in pairs {
            let sut = makeSUT(sync: input)
            await waitUntil { sut.state == expected }
            #expect(sut.state == expected)
        }
    }

    @Test("failed precedence is higher than an in-progress phase")
    func errorBeatsInProgress() async {
        let account = MockICloudAccountMonitor(initial: .available)
        let network = MockNetworkMonitor(initial: Self.online)
        let drive = MockICloudDriveMonitor(initial: .available)
        let sync = MockCloudKitSyncMonitor(initial: .importing)
        let real = CloudSyncMonitor(
            accountMonitor: account,
            networkMonitor: network,
            driveMonitor: drive,
            syncMonitor: sync,
            isDriveCheckEnabled: true,
            userDefaults: Self.makeDefaults()
        )
        real.hasCompletedInitialSync = true
        real.start()
        await waitUntil { real.state == .syncing(.importing) }

        sync.simulate(.error(message: "net down"))
        await waitUntil { real.state == .failed(message: "net down") }
        #expect(real.state == .failed(message: "net down"))
    }

    @Test("isPerformingInitialSync drives .initialSync state")
    func initialSyncState() async {
        let sut = makeSUT(sync: .setup, hasCompletedInitialSync: false)
        await waitUntil { sut.state == .initialSync }
        #expect(sut.isPerformingInitialSync)
        #expect(sut.state == .initialSync)
    }

    @Test(
        "After a successful import, .syncing(.setup) is no longer .initialSync"
    )
    func initialSyncEndsAfterImport() async {
        let am = MockICloudAccountMonitor(initial: .available)
        let nm = MockNetworkMonitor(initial: Self.online)
        let dm = MockICloudDriveMonitor(initial: .available)
        let sm = MockCloudKitSyncMonitor(initial: .idle)
        let sut = CloudSyncMonitor(
            accountMonitor: am,
            networkMonitor: nm,
            driveMonitor: dm,
            syncMonitor: sm,
            isDriveCheckEnabled: true,
            userDefaults: Self.makeDefaults()
        )
        sut.start()

        sm.simulate(
            event: CloudKitSyncEvent(
                type: .import,
                startDate: .now,
                endDate: .now,
                succeeded: true,
                errorDescription: nil
            )
        )
        await waitUntil { sut.hasCompletedInitialSync }

        sm.simulate(.setup)
        await waitUntil { sut.syncStatus == .setup }
        #expect(sut.state == .syncing(.setup))
    }
}

// MARK: - message(for:) policy filter

@MainActor
@Suite("CloudSyncMonitor.message(for:) filtering")
struct MessageForPolicyTests {
    
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
        network: NetworkStatus = MessageForPolicyTests.online,
        drive: ICloudDriveStatus = .available,
        sync: CloudKitSyncStatus = .idle,
        hasCompletedInitialSync: Bool = true
    ) -> CloudSyncMonitor {
        let sut = CloudSyncMonitor(
            accountMonitor: MockICloudAccountMonitor(initial: account),
            networkMonitor: MockNetworkMonitor(initial: network),
            driveMonitor: MockICloudDriveMonitor(initial: drive),
            syncMonitor: MockCloudKitSyncMonitor(initial: sync),
            isDriveCheckEnabled: true,
            userDefaults: Self.makeDefaults()
        )
        sut.hasCompletedInitialSync = hasCompletedInitialSync
        sut.start()
        return sut
    }
    
    // MARK: - Tests

    @Test(".ok always yields nil regardless of policy")
    func okAlwaysNil() async {
        let sut = makeSUT()
        await waitUntil { sut.state == .ok(lastSync: nil) }
        #expect(sut.message(for: .all) == nil)
        #expect(sut.message(for: .problemsOnly) == nil)
    }

    @Test(".problemsOnly hides .offline (network category)")
    func problemsOnlyHidesOffline() async {
        let sut = makeSUT(network: .disconnected)
        await waitUntil { sut.state == .offline }
        #expect(sut.message(for: .problemsOnly) == nil)
        #expect(sut.message(for: .all) == .offline)
    }

    @Test(".problemsOnly surfaces .signedOut (account category)")
    func problemsOnlyShowsSignedOut() async {
        let sut = makeSUT(account: .noAccount)
        await waitUntil { sut.state == .signedOut(.noAccount) }
        #expect(sut.message(for: .problemsOnly) == .signedOut(.noAccount))
    }

    @Test(".problemsOnly hides in-progress sync phases")
    func problemsOnlyHidesProgress() async {
        let sut = makeSUT(sync: .importing)
        await waitUntil { sut.state == .syncing(.importing) }
        #expect(sut.message(for: .problemsOnly) == nil)
        #expect(sut.message(for: .all) == .syncing(.importing))
    }

    @Test("Custom policy of just {.drive} surfaces only drive issues")
    func customPolicyIsolatesCategory() async {
        let driveOnly = CloudSyncMonitor.DisplayPolicy(categories: [.drive])

        let driveIssue = makeSUT(drive: .unavailable)
        await waitUntil { driveIssue.state == .driveDisabled }
        #expect(driveIssue.message(for: driveOnly) == .driveDisabled)

        let syncIssue = makeSUT(sync: .error(message: "x"))
        await waitUntil { syncIssue.state == .failed(message: "x") }
        #expect(syncIssue.message(for: driveOnly) == nil)
    }

    @Test("Empty policy hides everything (but .ok is still nil)")
    func emptyPolicyHidesEverything() async {
        let empty = CloudSyncMonitor.DisplayPolicy(categories: [])
        let sut = makeSUT(drive: .unavailable)
        await waitUntil { sut.state == .driveDisabled }
        #expect(sut.message(for: empty) == nil)
    }
}
