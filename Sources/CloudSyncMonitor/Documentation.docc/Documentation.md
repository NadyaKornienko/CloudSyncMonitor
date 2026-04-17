# ``CloudSyncMonitor``

A unified observer for iCloud account, network reachability, iCloud Drive
availability, and `NSPersistentCloudKitContainer` synchronization events.

## Overview

`CloudSyncMonitor` is a headless (UI-agnostic) library. It exposes observable
models only; rendering is left to the host application so it can match its
own design system.

The library aggregates four independent signals:

- **iCloud account status** — via `CKContainer.accountStatus()` and
  `Notification.Name.CKAccountChanged`.
- **Network reachability** — via `NWPathMonitor`.
- **iCloud Drive availability** — via `FileManager.ubiquityIdentityToken`
  and `Notification.Name.NSUbiquityIdentityDidChange`.
- **CloudKit sync events** — via
  `NSPersistentCloudKitContainer.eventChangedNotification`.

## Project configuration

In the host application enable the following capabilities:

1. **Signing & Capabilities → + Capability → iCloud**
   - Services: *CloudKit* and *iCloud Documents*
   - Add (or select) a CloudKit container.
2. **Signing & Capabilities → + Capability → Background Modes**
   - Enable *Remote notifications*.
3. **Signing & Capabilities → + Capability → Push Notifications**.
4. Configure your `NSPersistentCloudKitContainer` with persistent
   history tracking and remote change notifications:

   ```swift
   let description = container.persistentStoreDescriptions.first!
   description.setOption(true as NSNumber,
                         forKey: NSPersistentHistoryTrackingKey)
   description.setOption(true as NSNumber,
                         forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
