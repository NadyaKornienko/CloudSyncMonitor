//
//  CloudKitSyncStatus.swift
//  CloudSyncMonitor
//
//  Created by Nadezhda Kornienko on 17/4/2026.
//

import Foundation

/// High-level state of the Core Data + CloudKit synchronization pipeline.
///
/// The value is derived from ``CloudKitSyncMonitor`` which listens to
/// `NSPersistentCloudKitContainer.eventChangedNotification`.
public enum CloudKitSyncStatus: Equatable, Sendable {

    /// No sync event is currently in progress and no error is outstanding.
    case idle

    /// The container is performing initial schema / zone setup.
    case setup

    /// A remote import (download) is in progress.
    case importing

    /// A local export (upload) is in progress.
    case exporting

    /// The most recent sync event failed. `message` is a localized
    /// description of the underlying error.
    case error(message: String)

    /// `true` for any state in which CloudKit is actively working.
    public var isSyncing: Bool {
        switch self {
        case .setup, .importing, .exporting: return true
        default: return false
        }
    }

    /// `true` when the last event completed with an error.
    public var hasError: Bool {
        if case .error = self { return true }
        return false
    }

    /// The associated error message, if any.
    public var errorMessage: String? {
        if case .error(let message) = self { return message }
        return nil
    }
}
