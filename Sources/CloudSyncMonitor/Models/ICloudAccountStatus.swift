//
//  ICloudAccountStatus.swift
//  CloudSyncMonitor
//
//  Created by Nadezhda Kornienko on 17/4/2026.
//

import CloudKit

/// Represents the current iCloud account state of the device.
///
/// This is a plain, `Sendable` value type that can be safely passed across
/// concurrency domains and compared with `==`. It mirrors
/// [`CKAccountStatus`](https://developer.apple.com/documentation/cloudkit/ckaccountstatus)
/// but hides CloudKit as an implementation detail so consumers of this
/// library don't have to import `CloudKit` just to render a status badge.
///
/// ## Typical rendering rules
///
/// - ``available`` — everything is fine, sync can proceed.
/// - ``noAccount`` — prompt the user to sign in to iCloud.
/// - ``restricted`` — show an informational message (parental controls,
///   MDM profile, etc.).
/// - ``couldNotDetermine`` — transient, usually resolves after a refresh.
/// - ``temporarilyUnavailable`` — show a retry affordance.
public enum ICloudAccountStatus: Equatable, Sendable {

    /// The user is signed in and iCloud is reachable.
    case available

    /// No iCloud account is configured on the device.
    case noAccount

    /// iCloud is restricted by parental controls or a configuration profile.
    case restricted

    /// The status could not be determined (network issue, cold start, etc.).
    case couldNotDetermine

    /// The iCloud account is signed in but temporarily unavailable
    /// (e.g. the user must re-authenticate).
    case temporarilyUnavailable

    /// Creates a value from CloudKit's native status.
    ///
    /// - Parameter ckStatus: A `CKAccountStatus` obtained from
    ///   `CKContainer.accountStatus()`.
    public init(ckStatus: CKAccountStatus) {
        switch ckStatus {
        case .available: self = .available
        case .noAccount: self = .noAccount
        case .restricted: self = .restricted
        case .couldNotDetermine: self = .couldNotDetermine
        case .temporarilyUnavailable: self = .temporarilyUnavailable
        @unknown default: self = .couldNotDetermine
        }
    }

    /// A convenience flag indicating whether CloudKit operations can
    /// currently be attempted.
    public var isAvailable: Bool { self == .available }

    /// A short, human-readable description intended for debugging and
    /// logging. Do **not** use this string directly in the UI — localize
    /// it on the app side to match your tone of voice.
    public var debugDescription: String {
        switch self {
        case .available: return "iCloud account is available"
        case .noAccount: return "No iCloud account is signed in"
        case .restricted: return "iCloud account is restricted"
        case .couldNotDetermine: return "iCloud account status is unknown"
        case .temporarilyUnavailable: return "iCloud is temporarily unavailable"
        }
    }
}
