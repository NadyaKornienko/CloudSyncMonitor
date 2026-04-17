//
//  CloudSyncMonitorTests.swift
//  CloudSyncMonitorTests
//
//  Created by Nadezhda Kornienko on 17/4/2026.
//

import Foundation
import Testing

@testable import CloudSyncMonitor

@MainActor
@Suite("CloudSyncMonitor façade")
struct CloudSyncMonitorTests {

    // MARK: Helpers

    /// Spins up a façade wired to fresh mocks and returns everything so
    /// individual tests can drive the ports.
    private func makeSUT(
        account: ICloudAccountStatus = .couldNotDetermine,
        network: NetworkStatus = .disconnected,
        drive: ICloudDriveStatus = .unavailable,
        sync: CloudKitSyncStatus = .idle
    ) -> (
        sut: CloudSyncMonitor,
        account: MockICloudAccountMonitor,
        network: MockNetworkMonitor,
        drive: MockICloudDriveMonitor,
        sync: MockCloudKitSyncMonitor
    ) {
        let a = MockICloudAccountMonitor(initial: account)
        let n = MockNetworkMonitor(initial: network)
        let d = MockICloudDriveMonitor(initial: drive)
        let s = MockCloudKitSyncMonitor(initial: sync)
        let sut = CloudSyncMonitor(
            accountMonitor: a,
            networkMonitor: n,
            driveMonitor: d,
            syncMonitor: s
        )
        return (sut, a, n, d, s)
    }

    private static let online = NetworkStatus(
        isConnected: true,
        isExpensive: false,
        isConstrained: false,
        connectionType: .wifi
    )

    // MARK: Tests

    @Test("Initial state is fully pessimistic")
    func initialState() {
        let (sut, _, _, _, _) = makeSUT()

        #expect(sut.accountStatus == .couldNotDetermine)
        #expect(sut.networkStatus == .disconnected)
        #expect(sut.driveStatus == .unavailable)
        #expect(sut.syncStatus == .idle)
        #expect(sut.lastEvent == nil)
        #expect(!sut.canSync)
        #expect(!sut.isFullyOperational)
    }

    @Test("start() forwards to every port exactly once (idempotent)")
    func startIsIdempotent() {
        let (sut, a, n, d, s) = makeSUT()

        sut.start()
        sut.start()  // Second call must be a no-op.

        #expect(a.startCallCount == 1)
        #expect(n.startCallCount == 1)
        #expect(d.startCallCount == 1)
        #expect(s.startCallCount == 1)
    }

    @Test("stop() forwards to every port and is idempotent")
    func stopIsIdempotent() {
        let (sut, a, n, d, s) = makeSUT()

        sut.start()
        sut.stop()
        sut.stop()  // Second call must be a no-op.

        #expect(a.stopCallCount == 1)
        #expect(n.stopCallCount == 1)
        #expect(d.stopCallCount == 1)
        #expect(s.stopCallCount == 1)
    }

    @Test("Account status updates propagate to the façade")
    func accountStatusPropagation() async {
        let (sut, account, _, _, _) = makeSUT()
        sut.start()

        account.simulate(.available)
        await waitUntil { sut.accountStatus == .available }

        #expect(sut.accountStatus == .available)
    }

    @Test("Network status updates propagate to the façade")
    func networkStatusPropagation() async {
        let (sut, _, network, _, _) = makeSUT()
        sut.start()

        network.simulate(Self.online)
        await waitUntil { sut.networkStatus.isConnected }

        #expect(sut.networkStatus == Self.online)
    }

    @Test("iCloud Drive status updates propagate to the façade")
    func driveStatusPropagation() async {
        let (sut, _, _, drive, _) = makeSUT()
        sut.start()

        drive.simulate(.available)
        await waitUntil { sut.driveStatus == .available }

        #expect(sut.driveStatus == .available)
    }

    @Test("Sync status updates propagate to the façade")
    func syncStatusPropagation() async {
        let (sut, _, _, _, sync) = makeSUT()
        sut.start()

        sync.simulate(.importing)
        await waitUntil { sut.syncStatus == .importing }

        #expect(sut.syncStatus == .importing)
    }

    @Test("Sync events are forwarded to `lastEvent`")
    func syncEventsPropagation() async {
        let (sut, _, _, _, sync) = makeSUT()
        sut.start()

        let event = CloudKitSyncEvent(
            type: .export,
            startDate: .now,
            endDate: .now,
            succeeded: true,
            errorDescription: nil
        )
        sync.simulate(event: event)

        await waitUntil { sut.lastEvent?.id == event.id }
        #expect(sut.lastEvent == event)
    }

    @Test("canSync requires account + network + drive simultaneously")
    func canSyncTruthTable() async {
        let (sut, a, n, d, _) = makeSUT()
        sut.start()

        a.simulate(.available)
        await waitUntil { sut.accountStatus == .available }
        #expect(!sut.canSync, "Account alone is not enough")

        n.simulate(Self.online)
        await waitUntil { sut.networkStatus.isConnected }
        #expect(!sut.canSync, "Account + network without drive is not enough")

        d.simulate(.available)
        await waitUntil { sut.driveStatus == .available }
        #expect(
            sut.canSync,
            "All three conditions should yield canSync == true"
        )
    }

    @Test("isFullyOperational is false while the last event is an error")
    func isFullyOperationalGatesOnSyncStatus() async {
        let (sut, a, n, d, s) = makeSUT()
        sut.start()

        a.simulate(.available)
        n.simulate(Self.online)
        d.simulate(.available)
        await waitUntil { sut.canSync }
        #expect(sut.isFullyOperational)

        s.simulate(.error(message: "disk full"))
        await waitUntil { sut.syncStatus.hasError }
        #expect(!sut.isFullyOperational)

        s.simulate(.idle)
        await waitUntil { !sut.syncStatus.hasError }
        #expect(sut.isFullyOperational)
    }

    @Test("stop() detaches the pipeline so later updates are ignored")
    func stopDetachesPipeline() async {
        let (sut, account, _, _, _) = makeSUT()
        sut.start()

        account.simulate(.available)
        await waitUntil { sut.accountStatus == .available }

        sut.stop()
        account.simulate(.noAccount)

        // Allow the (now-detached) publisher a moment; state must not change.
        try? await Task.sleep(for: .milliseconds(50))
        #expect(sut.accountStatus == .available)
    }

    @Test("refreshAccount() delegates to the account port")
    func refreshAccountDelegates() async {
        let (sut, account, _, _, _) = makeSUT()
        await sut.refreshAccount()
        #expect(account.refreshCallCount == 1)
    }
}
