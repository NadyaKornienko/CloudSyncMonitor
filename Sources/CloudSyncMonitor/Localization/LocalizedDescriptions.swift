//
//  LocalizedDescriptions.swift
//  CloudSyncMonitor
//
//  Created by Nadezhda Kornienko on 18/4/2026.
//

//
//  User-facing localized descriptions for every public model.
//
//  Overriding in a host app
//  ========================
//  If you want different wording (tone of voice, brand phrasing, etc.),
//  ignore these properties and switch on the raw enum cases yourself.
//  They remain fully public and are the canonical source of truth.
//

import Foundation

// MARK: - ICloudAccountStatus

extension ICloudAccountStatus {

    /// A localized, user-facing description built from the library's
    /// bundled translations. Suitable for direct display in the UI.
    public var localizedDescription: String {
        switch self {
        case .available:
            return String(
                localized: "iCloudAccountStatus.available",
                defaultValue: "iCloud is available",
                bundle: .module,
                comment: "Status: iCloud account is signed in and reachable"
            )
        case .noAccount:
            return String(
                localized: "iCloudAccountStatus.noAccount",
                defaultValue: "No iCloud account is signed in",
                bundle: .module,
                comment: "Status: the user is not signed in to iCloud"
            )
        case .restricted:
            return String(
                localized: "iCloudAccountStatus.restricted",
                defaultValue: "iCloud access is restricted",
                bundle: .module,
                comment: "Status: iCloud restricted by parental controls or MDM"
            )
        case .couldNotDetermine:
            return String(
                localized: "iCloudAccountStatus.couldNotDetermine",
                defaultValue: "Unable to determine iCloud status",
                bundle: .module,
                comment: "Status: iCloud status is unknown, usually transient"
            )
        case .temporarilyUnavailable:
            return String(
                localized: "iCloudAccountStatus.temporarilyUnavailable",
                defaultValue: "iCloud is temporarily unavailable",
                bundle: .module,
                comment: "Status: iCloud requires re-authentication"
            )
        }
    }
}

// MARK: - ICloudDriveStatus

extension ICloudDriveStatus {

    /// A localized, user-facing description of iCloud Drive availability.
    public var localizedDescription: String {
        switch self {
        case .available:
            return String(
                localized: "iCloudDriveStatus.available",
                defaultValue: "iCloud Drive is available",
                bundle: .module,
                comment: "Status: ubiquity token is present"
            )
        case .unavailable:
            return String(
                localized: "iCloudDriveStatus.unavailable",
                defaultValue: "iCloud Drive is unavailable",
                bundle: .module,
                comment: "Status: ubiquity token is nil"
            )
        }
    }
}

// MARK: - NetworkStatus

extension NetworkStatus {

    /// A localized, user-facing description that combines reachability
    /// and the primary interface type.
    public var localizedDescription: String {
        guard isConnected else {
            return String(
                localized: "networkStatus.disconnected",
                defaultValue: "No network connection",
                bundle: .module,
                comment: "Status: no usable network path"
            )
        }
        return connectionType.localizedDescription
    }

    /// A localized badge for the Low Data Mode flag, or `nil` if not engaged.
    public var localizedConstrainedNote: String? {
        guard isConstrained else { return nil }
        return String(
            localized: "networkStatus.constrained",
            defaultValue: "Low Data Mode",
            bundle: .module,
            comment: "Badge: Low Data Mode is on"
        )
    }

    /// A localized badge for expensive (typically cellular) paths.
    public var localizedExpensiveNote: String? {
        guard isExpensive else { return nil }
        return String(
            localized: "networkStatus.expensive",
            defaultValue: "Expensive connection",
            bundle: .module,
            comment: "Badge: network is metered / paid"
        )
    }
}

extension NetworkStatus.ConnectionType {

    /// A localized label for the physical interface type.
    public var localizedDescription: String {
        switch self {
        case .wifi:
            return String(
                localized: "networkStatus.wifi",
                defaultValue: "Connected via Wi-Fi",
                bundle: .module,
                comment: "Interface: Wi-Fi"
            )
        case .cellular:
            return String(
                localized: "networkStatus.cellular",
                defaultValue: "Connected via cellular",
                bundle: .module,
                comment: "Interface: cellular data"
            )
        case .wiredEthernet:
            return String(
                localized: "networkStatus.wiredEthernet",
                defaultValue: "Connected via Ethernet",
                bundle: .module,
                comment: "Interface: wired Ethernet"
            )
        case .other:
            return String(
                localized: "networkStatus.other",
                defaultValue: "Connected",
                bundle: .module,
                comment: "Interface: unclassified"
            )
        case .none:
            return String(
                localized: "networkStatus.disconnected",
                defaultValue: "No network connection",
                bundle: .module,
                comment: "Interface: none / offline"
            )
        }
    }
}

// MARK: - CloudKitSyncStatus

extension CloudKitSyncStatus {

    /// A localized, user-facing description of the current sync state.
    ///
    /// For `.error`, the underlying `message` (which already comes from
    /// `NSError.localizedDescription` and is therefore OS-localized) is
    /// returned as-is; the generic "Sync error" string is used only when
    /// no message is attached.
    public var localizedDescription: String {
        switch self {
        case .idle:
            return String(
                localized: "cloudKitSyncStatus.idle",
                defaultValue: "Up to date",
                bundle: .module,
                comment: "Sync state: nothing to do"
            )
        case .setup:
            return String(
                localized: "cloudKitSyncStatus.setup",
                defaultValue: "Preparing sync…",
                bundle: .module,
                comment: "Sync state: initial setup"
            )
        case .importing:
            return String(
                localized: "cloudKitSyncStatus.importing",
                defaultValue: "Downloading changes…",
                bundle: .module,
                comment: "Sync state: remote → local"
            )
        case .exporting:
            return String(
                localized: "cloudKitSyncStatus.exporting",
                defaultValue: "Uploading changes…",
                bundle: .module,
                comment: "Sync state: local → remote"
            )
        case .error(let message) where !message.isEmpty:
            return message
        case .error:
            return String(
                localized: "cloudKitSyncStatus.error",
                defaultValue: "Sync error",
                bundle: .module,
                comment: "Sync state: generic error"
            )
        }
    }
}

// MARK: - CloudKitSyncEvent.EventType

extension CloudKitSyncEvent.EventType {

    /// A localized short label, suitable for a history list or badge.
    public var localizedTitle: String {
        switch self {
        case .setup:
            return String(
                localized: "cloudKitSyncEvent.setup",
                defaultValue: "Setup",
                bundle: .module,
                comment: "Event type: initial CloudKit setup"
            )
        case .`import`:
            return String(
                localized: "cloudKitSyncEvent.import",
                defaultValue: "Import",
                bundle: .module,
                comment: "Event type: remote → local import"
            )
        case .export:
            return String(
                localized: "cloudKitSyncEvent.export",
                defaultValue: "Export",
                bundle: .module,
                comment: "Event type: local → remote export"
            )
        }
    }
}

// MARK: - SettingsLauncher hint (iOS only — compiled where UIKit is available)

#if canImport(UIKit) && !os(watchOS) && !os(tvOS)
    extension SettingsLauncher {

        /// A localized hint telling the user exactly where in the Settings
        /// app they must navigate, since we cannot deep-link there directly.
        /// Use this string next to the "Open Settings" button.
        @MainActor
        public static var signInHint: String {
            String(
                localized: "settingsLauncher.signInHint",
                defaultValue: "Open Settings → Apple ID → iCloud to sign in",
                bundle: .module,
                comment: "Hint shown next to the Open Settings button"
            )
        }
    }
#endif // canImport(UIKit) && !os(watchOS) && !os(tvOS)
