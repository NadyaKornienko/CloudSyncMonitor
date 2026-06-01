//
//  CloudSyncMonitor+Extensions.swift
//  CloudSyncMonitor
//
//  Created by Nadezhda Kornienko on 22/4/2026.
//

import SwiftUI

// MARK: - SyncState

extension CloudSyncMonitor {

    public enum SyncState: Equatable, Sendable {

        /// Everything is fine. The optional `lastSync` is the timestamp
        /// of the most recent successful sync event, suitable for a
        /// settings-screen "Last synced …" label.
        case ok(lastSync: Date?)

        /// Very first sync after install is running.
        case initialSync

        /// An ongoing CloudKit sync phase.
        case syncing(Phase)

        /// No usable network path.
        case offline

        /// iCloud account is unavailable. The associated value carries
        /// the specific reason so UI can phrase the prompt correctly.
        case signedOut(ICloudAccountStatus)

        /// iCloud Drive is disabled for this app.
        case driveDisabled

        /// Preconditions are met but sync isn't running.
        case notSyncing

        /// The last sync event produced an error.
        case failed(message: String)

        public enum Phase: Sendable, Equatable {
            case setup, importing, exporting
        }

        public enum Severity: Sendable, Comparable {
            case info
            case warning
            case critical
        }

        public enum Category: Sendable, Hashable, CaseIterable {
            case none
            case progress
            case network
            case account
            case drive
            case sync
        }
    }
}

// MARK: - Convenience constructors

extension CloudSyncMonitor.SyncState {

    /// Shorthand for `.ok(lastSync: nil)` — handy in tests, previews and
    /// initial values where we don't yet know when the last sync was.
    public static let okUnknown: Self = .ok(lastSync: nil)
}

// MARK: - Severity & Category derivation

extension CloudSyncMonitor.SyncState {

    public var severity: Severity {
        switch self {
        case .ok, .initialSync, .syncing, .offline: return .info
        case .signedOut, .driveDisabled: return .warning
        case .notSyncing, .failed: return .critical
        }
    }

    public var category: Category {
        switch self {
        case .ok: return .none
        case .initialSync, .syncing: return .progress
        case .offline: return .network
        case .signedOut: return .account
        case .driveDisabled: return .drive
        case .notSyncing, .failed: return .sync
        }
    }

    public var isProgress: Bool { category == .progress }
    public var isProblem: Bool { severity != .info }
}

// MARK: - DisplayPolicy

extension CloudSyncMonitor {

    public struct DisplayPolicy: Sendable, Equatable {
        public var categories: Set<SyncState.Category>

        public init(categories: Set<SyncState.Category>) {
            self.categories = categories
        }

        public static let all = DisplayPolicy(
            categories: Set(SyncState.Category.allCases)
        )

        public static let problemsOnly = DisplayPolicy(
            categories: [.account, .drive, .sync]
        )
    }

    public func message(for policy: DisplayPolicy) -> SyncState? {
        let s = state
        if case .ok = s { return nil }  // .ok is never a banner
        return policy.categories.contains(s.category) ? s : nil
    }
}

// MARK: - Presentation (SF Symbols + colors)

extension CloudSyncMonitor.SyncState {

    public var symbolName: String {
        switch self {
        case .ok: return "checkmark.icloud"
        case .initialSync: return "icloud.and.arrow.down"
        case .syncing(.setup): return "icloud"
        case .syncing(.importing): return "icloud.and.arrow.down"
        case .syncing(.exporting): return "icloud.and.arrow.up"
        case .offline: return "bolt.horizontal.icloud"
        case .signedOut: return "person.crop.circle.badge.exclamationmark"
        case .driveDisabled: return "xmark.icloud"
        case .notSyncing: return "exclamationmark.icloud"
        case .failed: return "exclamationmark.icloud.fill"
        }
    }

    public var symbolColor: Color {
        switch severity {
        case .info: return .secondary
        case .warning: return .orange
        case .critical: return .red
        }
    }
}

// MARK: - Localized messages

extension CloudSyncMonitor.SyncState {

    /// A localized, user-facing message describing the current state.
    ///
    /// For `.ok(lastSync: nil)` returns an empty string — there is
    /// nothing useful to say. For `.ok(lastSync: someDate)` returns a
    /// "Last synced X ago" string.
    public var localizedMessage: String {
        switch self {

        case .ok(let lastSync):
            guard let lastSync else { return "" }
            
            let bundleLocale = Locale(identifier: Bundle.module.preferredLocalizations.first ?? "en")
            
            let relative = lastSync.formatted(.relative(presentation: .named, unitsStyle: .wide).locale(bundleLocale))

            return String(
                localized: "syncState.message.ok",
                defaultValue: "Last synced \(relative)",
                bundle: .module,
                comment: "Status: sync is up to date; %@ is a relative time"
            )

        case .initialSync:
            return String(
                localized: "syncState.message.initialSyncing",
                defaultValue: "Loading your data from iCloud…",
                bundle: .module,
                comment: "Banner: very first sync after install"
            )

        case .syncing(.setup):
            return String(
                localized: "syncState.message.syncing.setup",
                defaultValue: "Preparing iCloud sync…",
                bundle: .module,
                comment: "Banner: CloudKit is performing initial setup"
            )

        case .syncing(.importing):
            return String(
                localized: "syncState.message.syncing.importing",
                defaultValue: "Syncing from iCloud…",
                bundle: .module,
                comment: "Banner: remote → local import in progress"
            )

        case .syncing(.exporting):
            return String(
                localized: "syncState.message.syncing.exporting",
                defaultValue: "Saving to iCloud…",
                bundle: .module,
                comment: "Banner: local → remote export in progress"
            )

        case .offline:
            return String(
                localized: "syncState.message.offline",
                defaultValue:
                    "You're offline. Your changes are saved locally and will sync when you're back online.",
                bundle: .module,
                comment: "Banner: no network path; local edits queued"
            )

        case .signedOut(let s) where s == .noAccount:
            return String(
                localized: "syncState.message.signedOut.noAccount",
                defaultValue:
                    "Sign in to iCloud in Settings to sync your data across devices.",
                bundle: .module,
                comment: "Banner: user has no iCloud account on device"
            )

        case .signedOut:
            return String(
                localized: "syncState.message.signedOut.other",
                defaultValue:
                    "iCloud is unavailable. Your data won't sync until this is fixed.",
                bundle: .module,
                comment:
                    "Banner: iCloud account restricted / temporarily unavailable"
            )

        case .driveDisabled:
            return String(
                localized: "syncState.message.driveDisabled",
                defaultValue:
                    "Turn on iCloud Drive for this app in Settings to enable sync.",
                bundle: .module,
                comment: "Banner: iCloud Drive is off for this app"
            )

        case .notSyncing:
            return String(
                localized: "syncState.message.notSyncing",
                defaultValue:
                    "iCloud sync isn't running. Open Settings to check for issues.",
                bundle: .module,
                comment: "Banner: preconditions met but sync stalled"
            )

        case .failed(let msg):
            return String(
                localized: "syncState.message.failed",
                defaultValue: "iCloud sync failed: \(msg)",
                bundle: .module,
                comment:
                    "Banner: CloudKit returned an error; %@ is the underlying message"
            )
        }
    }
}
