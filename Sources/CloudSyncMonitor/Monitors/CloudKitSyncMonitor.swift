//
//  CloudKitSyncMonitor.swift
//  CloudSyncMonitor
//
//  Created by Nadezhda Kornienko on 17/4/2026.
//

import Combine
import CoreData
import Foundation

/// Abstraction over a Core Data + CloudKit sync-event observer.
@MainActor
public protocol CloudKitSyncMonitoring: AnyObject {

    /// Publishes the current ``CloudKitSyncStatus``.
    var statusPublisher: AnyPublisher<CloudKitSyncStatus, Never> { get }

    /// Publishes individual ``CloudKitSyncEvent`` values as they occur.
    var eventPublisher: AnyPublisher<CloudKitSyncEvent, Never> { get }

    /// The most recent status.
    var currentStatus: CloudKitSyncStatus { get }

    /// The most recently observed `setup` event, if any.
    var lastSetup: CloudKitSyncEvent? { get }

    /// The most recently observed `import` event, if any.
    var lastImport: CloudKitSyncEvent? { get }

    /// The most recently observed `export` event, if any.
    var lastExport: CloudKitSyncEvent? { get }

    /// Begins observing `NSPersistentCloudKitContainer.eventChangedNotification`.
    func start()

    /// Stops observing. Safe to call multiple times.
    func stop()
}

/// Production implementation that listens to the system-wide notification
/// posted by `NSPersistentCloudKitContainer`.
///
/// ## Host project requirements
///
/// For events to be delivered at all, the host's persistent store must be
/// configured with history tracking **and** remote change notifications:
///
/// ```swift
/// let description = container.persistentStoreDescriptions.first!
/// description.setOption(true as NSNumber,
///                       forKey: NSPersistentHistoryTrackingKey)
/// description.setOption(true as NSNumber,
///                       forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
/// ```
@MainActor
public final class CloudKitSyncMonitor: CloudKitSyncMonitoring {

    private let statusSubject = CurrentValueSubject<CloudKitSyncStatus, Never>(
        .idle
    )
    private let eventSubject = PassthroughSubject<CloudKitSyncEvent, Never>()
    private var cancellable: AnyCancellable?

    public private(set) var lastSetup: CloudKitSyncEvent?
    public private(set) var lastImport: CloudKitSyncEvent?
    public private(set) var lastExport: CloudKitSyncEvent?

    public var statusPublisher: AnyPublisher<CloudKitSyncStatus, Never> {
        statusSubject.eraseToAnyPublisher()
    }

    public var eventPublisher: AnyPublisher<CloudKitSyncEvent, Never> {
        eventSubject.eraseToAnyPublisher()
    }

    public var currentStatus: CloudKitSyncStatus { statusSubject.value }

    public init() {}

    public func start() {
        cancellable = NotificationCenter.default
            .publisher(
                for: NSPersistentCloudKitContainer.eventChangedNotification
            )
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard
                    let self,
                    let rawEvent = notification.userInfo?[
                        NSPersistentCloudKitContainer
                            .eventNotificationUserInfoKey
                    ] as? NSPersistentCloudKitContainer.Event
                else { return }
                self.handle(rawEvent: rawEvent)
            }
    }

    public func stop() {
        cancellable?.cancel()
        cancellable = nil
    }

    /// Maps a raw `NSPersistentCloudKitContainer.Event` into the library's
    /// public value type and updates cached `lastXxx` slots plus the
    /// current status.
    private func handle(rawEvent: NSPersistentCloudKitContainer.Event) {
        let type: CloudKitSyncEvent.EventType = {
            switch rawEvent.type {
            case .setup: return .setup
            case .import: return .import
            case .export: return .export
            @unknown default: return .setup
            }
        }()

        let event = CloudKitSyncEvent(
            type: type,
            startDate: rawEvent.startDate,
            endDate: rawEvent.endDate,
            succeeded: rawEvent.succeeded,
            errorDescription: rawEvent.error?.localizedDescription
        )

        // Keep the most recent event per kind for diagnostic UIs.
        switch type {
        case .setup: lastSetup = event
        case .import: lastImport = event
        case .export: lastExport = event
        }

        eventSubject.send(event)

        // Derive a high-level status. `endDate == nil` means the event is
        // still in progress; otherwise it has either succeeded or errored.
        if event.isInProgress {
            switch type {
            case .setup: statusSubject.send(.setup)
            case .import: statusSubject.send(.importing)
            case .export: statusSubject.send(.exporting)
            }
        } else if !event.succeeded, let message = event.errorDescription {
            statusSubject.send(.error(message: message))
        } else {
            statusSubject.send(.idle)
        }
    }
}
