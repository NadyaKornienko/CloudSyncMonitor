//
//  ICloudAccountMonitor.swift
//  CloudSyncMonitor
//
//  Created by Nadezhda Kornienko on 17/4/2026.
//

import CloudKit
import Combine

/// Abstraction over an iCloud account observer, designed for dependency
/// injection and testability.
///
/// Use ``ICloudAccountMonitor`` for the production implementation, or
/// provide your own mock that drives ``statusPublisher`` from a
/// `CurrentValueSubject` for unit tests.
@MainActor
public protocol ICloudAccountMonitoring: AnyObject {

    /// A publisher that emits the latest ``ICloudAccountStatus`` on
    /// subscription and every time the status changes.
    var statusPublisher: AnyPublisher<ICloudAccountStatus, Never> { get }

    /// The most recently observed status.
    var currentStatus: ICloudAccountStatus { get }

    /// Begins observing `CKAccountChanged` and kicks off an initial refresh.
    func start()

    /// Stops observing. Safe to call multiple times.
    func stop()

    /// Forces an immediate refresh of the account status from CloudKit.
    func refresh() async
}

/// Production implementation backed by a ``CKContainer``.
///
/// - Important: Instantiate this on the main actor. The class schedules
///   its refreshes on `MainActor` to keep ``currentStatus`` consistent
///   with SwiftUI view updates.
@MainActor
public final class ICloudAccountMonitor: ICloudAccountMonitoring {

    private let subject = CurrentValueSubject<ICloudAccountStatus, Never>(
        .couldNotDetermine
    )
    private var cancellable: AnyCancellable?
    private let container: CKContainer

    public var statusPublisher: AnyPublisher<ICloudAccountStatus, Never> {
        subject.eraseToAnyPublisher()
    }

    public var currentStatus: ICloudAccountStatus { subject.value }

    /// Creates a monitor bound to a specific CloudKit container.
    ///
    /// - Parameter container: The container to query. Defaults to
    ///   `CKContainer.default()`, which uses the container configured
    ///   in the app's entitlements.
    public init(container: CKContainer = .default()) {
        self.container = container
    }

    public func start() {
        cancellable = NotificationCenter.default
            .publisher(for: .CKAccountChanged)
            .sink { [weak self] _ in
                Task { [weak self] in await self?.refresh() }
            }

        Task { [weak self] in await self?.refresh() }
    }

    public func stop() {
        cancellable?.cancel()
        cancellable = nil
    }

    public func refresh() async {
        do {
            let status = try await container.accountStatus()
            subject.send(ICloudAccountStatus(ckStatus: status))
        } catch {
            subject.send(.couldNotDetermine)
        }
    }
}
