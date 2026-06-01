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
/// ## Usage
///
/// ```swift
/// @main
/// struct MyApp: App {
///     @State private var syncMonitor = CloudSyncMonitor()
///
///     var body: some Scene {
///         WindowGroup {
///             RootView()
///                 .cloudSyncMonitor(syncMonitor)   // injects + auto-starts
///         }
///     }
/// }
///
/// struct RootView: View {
///     @Environment(CloudSyncMonitor.self) private var syncMonitor
///
///     var body: some View {
///         Label(syncMonitor.syncStatus.isSyncing ? "Syncing…" : "Up to date",
///               systemImage: "icloud")
///     }
/// }
/// ```
///
/// ## Testing
///
/// All four monitors are injected via protocols and can be replaced with
/// mocks that publish values through a `CurrentValueSubject`.
/// Inject an isolated `UserDefaults` suite to keep tests hermetic:
///
/// ```swift
/// let syncMonitor = CloudSyncMonitor(
///     accountMonitor: MockAccountMonitor(),
///     networkMonitor: MockNetworkMonitor(),
///     driveMonitor:   MockDriveMonitor(),
///     syncMonitor:    MockSyncMonitor(),
///     userDefaults:   isolatedDefaults
/// )
/// ```
@Observable
@MainActor
public final class CloudSyncMonitor {

    // MARK: - Persistent state

    /// UserDefaults key. Flag is set once and forever after CloudKit has
    /// successfully imported data at least once.
    private static let initialSyncKey =
        "CloudSyncMonitor.hasCompletedInitialSync"
    private static let lastSyncDateKey = "CloudSyncMonitor.lastSyncDate"

    /// `true` if this device has successfully completed at least one iCloud import.
    /// After installation = `false`, after first successful import = `true` forever.
    public var hasCompletedInitialSync: Bool {
        get { defaults.bool(forKey: Self.initialSyncKey) }
        set { defaults.set(newValue, forKey: Self.initialSyncKey) }
    }

    /// `true` while the *very first* sync (setup/import/export) is in progress
    /// and it has never completed successfully before.
    ///
    /// Use this to show a "Loading your data from iCloud…" banner on a freshly
    /// installed app, but **not** show it on every regular in‑progress import
    /// in the future.
    public var isPerformingInitialSync: Bool {
        syncStatus.isSyncing && !hasCompletedInitialSync
    }

    /// The most recent successful sync date, persisted across app launches.
    public private(set) var lastSyncDate: Date? {
        get { defaults.object(forKey: Self.lastSyncDateKey) as? Date }
        set { defaults.set(newValue, forKey: Self.lastSyncDateKey) }
    }

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
    public private(set) var lastEvent: CloudKitSyncEvent? {
        didSet { applyEventSideEffects() }
    }

    // MARK: - Injected ports

    /// The underlying account monitor. Exposed for advanced scenarios
    /// (e.g. triggering a manual refresh).
    @ObservationIgnored
    public let accountMonitor: any ICloudAccountMonitoring

    /// The underlying network monitor.
    @ObservationIgnored
    public let networkMonitor: any NetworkMonitoring

    /// The underlying iCloud Drive monitor.
    @ObservationIgnored
    public let driveMonitor: any ICloudDriveMonitoring

    /// The underlying sync-event monitor.
    @ObservationIgnored
    public let syncMonitor: any CloudKitSyncMonitoring

    /// The backing store for persisted flags (`hasCompletedInitialSync`, `lastSyncDate`).
    @ObservationIgnored
    private let defaults: UserDefaults

    // MARK: - Configuration

    /// Controls whether iCloud Drive availability affects the derived `state`.
    ///
    /// Set to `true` if your app syncs user documents via iCloud Drive.
    /// Set to `false` (default) for pure CloudKit / Core Data + CloudKit apps.
    ///
    /// Can be changed at runtime. When `false`, `.driveDisabled` state is
    /// never returned, regardless of actual Drive availability.
    @ObservationIgnored
    public var isDriveCheckEnabled: Bool = false

    /// How long to stay in the green-but-silent state before declaring
    /// ``isSilentlyNotSyncing``. Default: 30 seconds.
    @ObservationIgnored
    public var silentSyncGracePeriod: Duration = .seconds(30)

    /// Set to `true` by the grace timer once preconditions have been
    /// met for longer than ``silentSyncGracePeriod`` with no activity.
    /// Observed by ``state``; callers should not mutate it directly.
    public private(set) var hasExceededSilentGrace: Bool = false

    @ObservationIgnored
    private var silentGraceTask: Task<Void, Never>?

    // MARK: - Private

    @ObservationIgnored
    private var cancellables = Set<AnyCancellable>()

    @ObservationIgnored
    private var isRunning = false

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
    ///   - isDriveCheckEnabled: Whether Drive availability gates ``canSync``.
    ///   - userDefaults:   Backing store for persisted flags. Inject a
    ///     custom suite in tests to keep them hermetic.
    public init(
        accountMonitor: any ICloudAccountMonitoring = ICloudAccountMonitor(),
        networkMonitor: any NetworkMonitoring = NetworkMonitor(),
        driveMonitor: any ICloudDriveMonitoring = ICloudDriveMonitor(),
        syncMonitor: any CloudKitSyncMonitoring = CloudKitSyncMonitor(),
        isDriveCheckEnabled: Bool = false,
        userDefaults: UserDefaults = .standard
    ) {
        self.accountMonitor = accountMonitor
        self.networkMonitor = networkMonitor
        self.driveMonitor = driveMonitor
        self.syncMonitor = syncMonitor
        self.isDriveCheckEnabled = isDriveCheckEnabled
        self.defaults = userDefaults
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
            .sink { [weak self] in
                self?.accountStatus = $0
                self?.rescheduleSilentGrace()
            }
            .store(in: &cancellables)

        networkMonitor.statusPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.networkStatus = $0
                self?.rescheduleSilentGrace()
            }
            .store(in: &cancellables)

        driveMonitor.statusPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.driveStatus = $0
                self?.rescheduleSilentGrace()
            }
            .store(in: &cancellables)

        syncMonitor.statusPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.syncStatus = $0
                self?.rescheduleSilentGrace()
            }
            .store(in: &cancellables)

        syncMonitor.eventPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                guard let self else { return }
                // Single source of truth: `lastEvent.didSet` handles
                // `lastSyncDate` and `hasCompletedInitialSync`.
                self.lastEvent = event
                self.rescheduleSilentGrace()
            }
            .store(in: &cancellables)

        accountMonitor.start()
        networkMonitor.start()
        driveMonitor.start()
        syncMonitor.start()

        rescheduleSilentGrace()
    }

    /// Tears down all subscriptions and stops every underlying monitor.
    public func stop() {
        guard isRunning else { return }
        isRunning = false
        cancellables.removeAll()
        silentGraceTask?.cancel()
        silentGraceTask = nil
        hasExceededSilentGrace = false
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
    /// Drive is available (if ``isDriveCheckEnabled`` is `true`).
    public var canSync: Bool {
        accountStatus.isAvailable
            && networkStatus.isConnected
            && (!isDriveCheckEnabled || driveStatus.isAvailable)
    }

    /// `true` when ``canSync`` is satisfied **and** the most recent sync
    /// event did not produce an error.
    public var isFullyOperational: Bool {
        canSync && !syncStatus.hasError
    }

    /// `true` when preconditions are met but no sync activity observed
    /// for longer than `silentSyncGracePeriod`.
    private var isSilentlyNotSyncing: Bool {
        canSync && hasExceededSilentGrace && syncStatus == .idle
    }

    /// The single, high-level sync state derived from all monitors.
    /// Computed property - automatically updates when dependencies change.
    public var state: SyncState {
        // Highest priority: network issues
        if !networkStatus.isConnected { return .offline }

        // Account issues
        if !accountStatus.isAvailable { return .signedOut(accountStatus) }

        // Drive issues (only if checking is enabled)
        if isDriveCheckEnabled && !driveStatus.isAvailable {
            return .driveDisabled
        }

        // Sync errors
        if case .error(let msg) = syncStatus { return .failed(message: msg) }

        // Silent grace period exceeded (no activity)
        if isSilentlyNotSyncing { return .notSyncing }

        // First sync after install
        if isPerformingInitialSync { return .initialSync }

        // Active sync states
        switch syncStatus {
        case .importing: return .syncing(.importing)
        case .exporting: return .syncing(.exporting)
        case .setup: return .syncing(.setup)
        // Idle/healthy states
        case .idle: return .ok(lastSync: lastSyncDate)
        case .error: return .ok(lastSync: lastSyncDate)  // Unreachable: intercepted above.
        }
    }

    // MARK: - Private Helpers

    /// Single place that mutates persisted state in response to a new event.
    private func applyEventSideEffects() {
        guard
            let event = lastEvent,
            event.succeeded,
            let endDate = event.endDate,
            endDate > (lastSyncDate ?? .distantPast)
        else { return }

        lastSyncDate = endDate

        if event.type == .import {
            hasCompletedInitialSync = true
        }
    }

    /// Arms the grace timer whenever the pipeline is "green and idle".
    ///
    /// The timer is re-armed on every status change. If a new sync event
    /// fires during the sleep, the task captured `lastActivity` snapshot
    /// will not match the new `lastEvent.endDate` and the flag stays `false`.
    private func rescheduleSilentGrace() {
        silentGraceTask?.cancel()
        silentGraceTask = nil
        hasExceededSilentGrace = false

        // Arm whenever preconditions are met and CloudKit is idle — regardless
        // of whether we've seen events before. Past events do not disqualify
        // the timer; only *new* activity during the sleep does.
        guard canSync, syncStatus == .idle else { return }

        let grace = silentSyncGracePeriod
        let lastActivity = lastEvent?.endDate ?? .distantPast

        silentGraceTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: grace)

            guard let self,
                !Task.isCancelled,
                self.canSync,
                self.syncStatus == .idle,
                (self.lastEvent?.endDate ?? .distantPast) == lastActivity
            else { return }

            self.hasExceededSilentGrace = true
        }
    }
}
