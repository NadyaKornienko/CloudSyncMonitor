//
//  CloudSyncMonitor.swift
//  CloudSyncMonitor
//
//  Created by Nadezhda Kornienko on 17/4/2026.
//

import CloudKit
import Combine
import Foundation
import Observation

/// Aggregates iCloud account, network, iCloud Drive, and CloudKit sync
/// signals into a single observable model.
///
/// ## Usage in SwiftUI
///
/// ```swift
/// @main
/// struct MyApp: App {
///     @State private var cloud = CloudSyncMonitor()
///
///     var body: some Scene {
///         WindowGroup {
///             RootView()
///                 .cloudSyncMonitor(cloud)   // injects + auto-starts
///         }
///     }
/// }
///
/// struct RootView: View {
///     @Environment(CloudSyncMonitor.self) private var cloud
///
///     var body: some View {
///         Label(cloud.syncStatus.isSyncing ? "Syncing…" : "Up to date",
///               systemImage: "icloud")
///     }
/// }
/// ```
///
/// ## Testing
///
/// All four monitors are injected via protocols and can be replaced with
/// mocks that publish values through a `CurrentValueSubject`:
///
/// ```swift
/// let cloud = CloudSyncMonitor(
///     accountMonitor: MockAccountMonitor(),
///     networkMonitor: MockNetworkMonitor(),
///     driveMonitor:   MockDriveMonitor(),
///     syncMonitor:    MockSyncMonitor()
/// )
/// ```

@Observable
@MainActor
public final class CloudSyncMonitor {

    // MARK: - Observable state

    /// Last known iCloud account status.
    public private(set) var accountStatus: ICloudAccountStatus =
        .couldNotDetermine

    /// Last known network reachability.
    public private(set) var networkStatus: NetworkStatus = .disconnected

    /// Last known iCloud Drive availability.
    public private(set) var driveStatus: ICloudDriveStatus = .unavailable

    /// Last known CloudKit sync status (setup / import / export / error / idle).
    public private(set) var syncStatus: CloudKitSyncStatus = .idle

    /// The most recently received sync event, useful for timeline UIs.
    public private(set) var lastEvent: CloudKitSyncEvent?

    // MARK: - Injected ports

    /// The underlying account monitor. Exposed for advanced scenarios
    /// (e.g. triggering a manual refresh).
    @ObservationIgnored public let accountMonitor: any ICloudAccountMonitoring

    /// The underlying network monitor.
    @ObservationIgnored public let networkMonitor: any NetworkMonitoring

    /// The underlying iCloud Drive monitor.
    @ObservationIgnored public let driveMonitor: any ICloudDriveMonitoring

    /// The underlying sync-event monitor.
    @ObservationIgnored public let syncMonitor: any CloudKitSyncMonitoring

    // MARK: - Private

    @ObservationIgnored private var cancellables = Set<AnyCancellable>()
    @ObservationIgnored private var isRunning = false

    // MARK: - Init

    /// Creates a new monitor.
    ///
    /// All parameters have sensible defaults backed by the production
    /// implementations. Provide your own conformances in tests or when
    /// you want to share a single `CKContainer` across the app.
    ///
    /// - Parameters:
    ///   - accountMonitor: The iCloud account observer.
    ///   - networkMonitor: The network reachability observer.
    ///   - driveMonitor:   The iCloud Drive availability observer.
    ///   - syncMonitor:    The CloudKit sync-event observer.
    public init(
        accountMonitor: any ICloudAccountMonitoring = ICloudAccountMonitor(),
        networkMonitor: any NetworkMonitoring = NetworkMonitor(),
        driveMonitor: any ICloudDriveMonitoring = ICloudDriveMonitor(),
        syncMonitor: any CloudKitSyncMonitoring = CloudKitSyncMonitor()
    ) {
        self.accountMonitor = accountMonitor
        self.networkMonitor = networkMonitor
        self.driveMonitor = driveMonitor
        self.syncMonitor = syncMonitor
    }

    // MARK: - Lifecycle

    /// Wires up all publishers and starts every underlying monitor.
    ///
    /// Calling `start()` multiple times is a no-op. Prefer using
    /// ``SwiftUICore/View/cloudSyncMonitor(_:autoStart:)`` which handles
    /// lifecycle for you.
    public func start() {
        guard !isRunning else { return }
        isRunning = true

        accountMonitor.statusPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.accountStatus = $0 }
            .store(in: &cancellables)

        networkMonitor.statusPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.networkStatus = $0 }
            .store(in: &cancellables)

        driveMonitor.statusPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.driveStatus = $0 }
            .store(in: &cancellables)

        syncMonitor.statusPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.syncStatus = $0 }
            .store(in: &cancellables)

        syncMonitor.eventPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.lastEvent = $0 }
            .store(in: &cancellables)

        accountMonitor.start()
        networkMonitor.start()
        driveMonitor.start()
        syncMonitor.start()
    }

    /// Tears down all subscriptions and stops every underlying monitor.
    public func stop() {
        guard isRunning else { return }
        isRunning = false
        cancellables.removeAll()
        accountMonitor.stop()
        networkMonitor.stop()
        driveMonitor.stop()
        syncMonitor.stop()
    }

    /// Forces an immediate refresh of the iCloud account status.
    public func refreshAccount() async {
        await accountMonitor.refresh()
    }

    // MARK: - Derived state

    /// `true` when every precondition for CloudKit sync is currently met:
    /// the user is signed in, the device has a network path, and iCloud
    /// Drive is available.
    public var canSync: Bool {
        accountStatus.isAvailable
            && networkStatus.isConnected
            && driveStatus.isAvailable
    }

    /// `true` when ``canSync`` is satisfied **and** the most recent sync
    /// event did not produce an error.
    public var isFullyOperational: Bool {
        canSync && !syncStatus.hasError
    }
}
