//
//  NetworkMonitor.swift
//  CloudSyncMonitor
//
//  Created by Nadezhda Kornienko on 17/4/2026.
//

import Combine
import Foundation
import Network

/// Abstraction over a reachability observer.
public protocol NetworkMonitoring: AnyObject {

    /// Publishes the latest ``NetworkStatus`` on subscription and every
    /// time the underlying `NWPath` changes.
    var statusPublisher: AnyPublisher<NetworkStatus, Never> { get }

    /// The most recently observed status.
    var currentStatus: NetworkStatus { get }

    /// Begins monitoring the default network path.
    func start()

    /// Stops monitoring. Safe to call multiple times.
    func stop()
}

/// Production implementation backed by `NWPathMonitor`.
///
/// The internal `NWPathMonitor` callback fires on a dedicated background
/// queue; updates are re-dispatched to the main queue before being sent
/// through ``statusPublisher``, which matches SwiftUI's expectations.
public final class NetworkMonitor: NetworkMonitoring, @unchecked Sendable {

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "CloudSyncMonitor.NetworkMonitor")
    private let subject = CurrentValueSubject<NetworkStatus, Never>(
        .disconnected
    )
    private let lock = NSLock()
    private var started = false

    public var statusPublisher: AnyPublisher<NetworkStatus, Never> {
        subject.eraseToAnyPublisher()
    }

    public var currentStatus: NetworkStatus { subject.value }

    public init() {}

    public func start() {
        lock.lock()
        defer { lock.unlock() }
        guard !started else { return }
        started = true

        monitor.pathUpdateHandler = { [weak self] path in
            self?.subject.send(Self.map(path: path))
        }
        monitor.start(queue: queue)
    }

    public func stop() {
        lock.lock()
        defer { lock.unlock() }
        guard started else { return }
        started = false
        monitor.cancel()
    }

    /// Maps a raw `NWPath` into the library's public `NetworkStatus`.
    private static func map(path: NWPath) -> NetworkStatus {
        let type: NetworkStatus.ConnectionType = {
            if path.usesInterfaceType(.wifi) { return .wifi }
            if path.usesInterfaceType(.cellular) { return .cellular }
            if path.usesInterfaceType(.wiredEthernet) { return .wiredEthernet }
            if path.status == .satisfied { return .other }
            return .none
        }()

        return NetworkStatus(
            isConnected: path.status == .satisfied,
            isExpensive: path.isExpensive,
            isConstrained: path.isConstrained,
            connectionType: type
        )
    }
}
