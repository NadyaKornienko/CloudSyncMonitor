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

    /// Event types currently in flight. Import and export can overlap, so
    /// one phase finishing must not report `.idle` while another still runs.
    private var inProgress: Set<CloudKitSyncEvent.EventType> = []

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
            .sink { @MainActor [weak self] notification in
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
        inProgress.removeAll()
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

        if event.isInProgress {
            inProgress.insert(type)
        } else {
            inProgress.remove(type)
        }

        // Keep the most recent event per kind for diagnostic UIs.
        switch type {
        case .setup: lastSetup = event
        case .import: lastImport = event
        case .export: lastExport = event
        }

        eventSubject.send(event)
        statusSubject.send(Self.status(after: event, inProgress: inProgress))
    }

    /// Derives the high-level status from the freshest event plus the set of
    /// phases still in flight. A finished failing event surfaces as `.error`
    /// (an empty message falls back to a generic localized description);
    /// otherwise the most significant running phase wins. Internal for
    /// unit testing.
    static func status(
        after event: CloudKitSyncEvent,
        inProgress: Set<CloudKitSyncEvent.EventType>
    ) -> CloudKitSyncStatus {
        if !event.isInProgress, !event.succeeded {
            return .error(message: event.errorDescription ?? "")
        }
        if inProgress.contains(.setup) { return .setup }
        if inProgress.contains(.import) { return .importing }
        if inProgress.contains(.export) { return .exporting }
        return .idle
    }
}
