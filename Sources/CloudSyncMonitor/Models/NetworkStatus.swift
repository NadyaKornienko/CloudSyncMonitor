//
//  NetworkStatus.swift
//  CloudSyncMonitor
//
//  Created by Nadezhda Kornienko on 17/4/2026.
//

import Foundation

/// A snapshot of the device's current network reachability.
///
/// Values are produced by ``NetworkMonitor`` from an underlying
/// `NWPathMonitor`. The structure is `Sendable` and `Equatable` so it
/// integrates cleanly with `@Observable` state and SwiftUI diffing.
public struct NetworkStatus: Equatable, Sendable {

    /// The physical interface carrying the current connection, if any.
    public enum ConnectionType: Sendable, Equatable {
        /// The device is connected via Wi-Fi.
        case wifi
        /// The device is connected via cellular data.
        case cellular
        /// The device is connected via wired Ethernet (iPad / Mac).
        case wiredEthernet
        /// The device has a satisfied path but the interface could not
        /// be classified (loopback, VPN-only, etc.).
        case other
        /// The device currently has no usable network path.
        case none
    }

    /// `true` when `NWPath.status == .satisfied`.
    public let isConnected: Bool

    /// `true` when the network is considered expensive (typically cellular
    /// or a personal hotspot). Mirrors `NWPath.isExpensive`.
    public let isExpensive: Bool

    /// `true` when Low Data Mode is engaged for this path.
    /// Mirrors `NWPath.isConstrained`.
    public let isConstrained: Bool

    /// The primary interface type of the current path.
    public let connectionType: ConnectionType

    /// Memberwise initializer. Primarily useful for previews and tests;
    /// production values are produced by ``NetworkMonitor``.
    public init(
        isConnected: Bool,
        isExpensive: Bool,
        isConstrained: Bool,
        connectionType: ConnectionType
    ) {
        self.isConnected = isConnected
        self.isExpensive = isExpensive
        self.isConstrained = isConstrained
        self.connectionType = connectionType
    }

    /// A canonical "offline" value used as the initial state.
    public static let disconnected = NetworkStatus(
        isConnected: false,
        isExpensive: false,
        isConstrained: false,
        connectionType: .none
    )
}
