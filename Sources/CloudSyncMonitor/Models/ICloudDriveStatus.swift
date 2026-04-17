//
//  ICloudDriveStatus.swift
//  CloudSyncMonitor
//
//  Created by Nadezhda Kornienko on 17/4/2026.
//

import Foundation

/// Availability of iCloud Drive (the ubiquity identity token) on the device.
///
/// This does **not** indicate whether files have finished downloading; it
/// only reflects whether an iCloud identity is currently active. When this
/// flips from ``available`` to ``unavailable`` the app should treat all
/// previously-obtained ubiquity URLs as invalidated.
public enum ICloudDriveStatus: Equatable, Sendable {

    /// `FileManager.default.ubiquityIdentityToken` is non-nil.
    case available

    /// `FileManager.default.ubiquityIdentityToken` is nil
    /// (signed out, restricted, or never configured).
    case unavailable

    /// Convenience flag.
    public var isAvailable: Bool { self == .available }
}
