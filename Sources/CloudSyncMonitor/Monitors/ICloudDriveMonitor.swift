//
//  ICloudDriveMonitor.swift
//  CloudSyncMonitor
//
//  Created by Nadezhda Kornienko on 17/4/2026.
//

import Combine
import Foundation

/// Abstraction over an iCloud Drive availability observer.
@MainActor
public protocol ICloudDriveMonitoring: AnyObject {

    /// Publishes the latest ``ICloudDriveStatus`` on subscription and every
    /// time `NSUbiquityIdentityDidChange` fires.
    var statusPublisher: AnyPublisher<ICloudDriveStatus, Never> { get }

    /// The most recently observed status.
    var currentStatus: ICloudDriveStatus { get }

    /// Begins observing ubiquity-identity changes.
    func start()

    /// Stops observing. Safe to call multiple times.
    func stop()
}

/// Production implementation backed by `FileManager.ubiquityIdentityToken`.
@MainActor
public final class ICloudDriveMonitor: ICloudDriveMonitoring {

    private let subject: CurrentValueSubject<ICloudDriveStatus, Never>
    private var cancellable: AnyCancellable?

    public var statusPublisher: AnyPublisher<ICloudDriveStatus, Never> {
        subject.eraseToAnyPublisher()
    }

    public var currentStatus: ICloudDriveStatus { subject.value }

    public init() {
        let initial: ICloudDriveStatus =
            FileManager.default.ubiquityIdentityToken != nil
            ? .available : .unavailable
        self.subject = CurrentValueSubject(initial)
    }

    public func start() {
        refresh()
        cancellable = NotificationCenter.default
            .publisher(for: .NSUbiquityIdentityDidChange)
            .sink { [weak self] _ in self?.refresh() }
    }

    public func stop() {
        cancellable?.cancel()
        cancellable = nil
    }

    /// Re-reads the ubiquity token and publishes the derived status.
    private func refresh() {
        let status: ICloudDriveStatus =
            FileManager.default.ubiquityIdentityToken != nil
            ? .available : .unavailable
        subject.send(status)
    }
}
