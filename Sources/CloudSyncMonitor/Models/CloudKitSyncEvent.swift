//
//  CloudKitSyncEvent.swift
//  CloudSyncMonitor
//
//  Created by Nadezhda Kornienko on 17/4/2026.
//

import Foundation

/// A flattened, `Sendable` description of a single CloudKit sync event.
///
/// Produced by ``CloudKitSyncMonitor`` and suitable for logging, history
/// lists, and diagnostics UIs.
public struct CloudKitSyncEvent: Identifiable, Equatable, Sendable {

    /// The kind of work the container was performing.
    public enum EventType: String, Sendable, Equatable {
        case setup
        case `import`
        case export
    }

    /// A stable identifier generated at the moment the event is captured.
    public let id: UUID

    /// The kind of sync work this event represents.
    public let type: EventType

    /// Timestamp at which the event began.
    public let startDate: Date

    /// Timestamp at which the event ended. `nil` means the event is still
    /// in progress.
    public let endDate: Date?

    /// Whether the event completed successfully.
    public let succeeded: Bool

    /// A localized error description, if the event produced an error.
    public let errorDescription: String?

    /// Memberwise initializer. Intended primarily for tests and previews.
    public init(
        id: UUID = UUID(),
        type: EventType,
        startDate: Date,
        endDate: Date?,
        succeeded: Bool,
        errorDescription: String?
    ) {
        self.id = id
        self.type = type
        self.startDate = startDate
        self.endDate = endDate
        self.succeeded = succeeded
        self.errorDescription = errorDescription
    }

    /// `true` while the event has not yet completed.
    public var isInProgress: Bool { endDate == nil }
}
