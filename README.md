# CloudSyncMonitor

A headless Swift package that reports the state of everything that can
break iCloud sync in a Core Data + CloudKit SwiftUI app:

- iCloud account status (`CKAccountStatus`)
- Network reachability (`NWPathMonitor`)
- iCloud Drive availability (`ubiquityIdentityToken`)
- CloudKit sync events (`NSPersistentCloudKitContainer.eventChangedNotification`)

The library exposes **models only** — you render the UI in your app's own
design language.

## Requirements

| Platform  | Minimum version |
|-----------|-----------------|
| iOS       | 17.4            |
| watchOS   | 11.5            |
| macOS     | 14.4            |
| tvOS      | 17.4            |
| visionOS  | 1.1             |
| Swift     | 6.0             |

## Installation (Swift Package Manager)

In Xcode: **File → Add Package Dependencies…** and paste the repository URL.

Or, in `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/NadyaKornienko/CloudSyncMonitor.git", from: "1.0.0")
],
targets: [
    .target(
        name: "MyApp", // Where "MyApp" is the name of your app
        dependencies: ["CloudSyncMonitor"])
]
```

## Host project configuration

1. **Capabilities**
   - iCloud → *CloudKit* + *iCloud Documents*, with a container selected.
   - Background Modes → *Remote notifications*.
   - Push Notifications.

2. **Core Data store description** — required for
   `NSPersistentCloudKitContainer.eventChangedNotification` to fire:

   ```swift
   let description = container.persistentStoreDescriptions.first!
   description.setOption(true as NSNumber,
                         forKey: NSPersistentHistoryTrackingKey)
   description.setOption(true as NSNumber,
                         forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
   ```

## Quick start

```swift
import SwiftUI
import CloudSyncMonitor

@main
struct MyApp: App {
    @State private var cloud = CloudSyncMonitor()
    let persistence = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.managedObjectContext,
                             persistence.container.viewContext)
                .cloudSyncMonitor(cloud)
        }
    }
}

struct CloudStatusBadge: View {
    @Environment(CloudSyncMonitor.self) private var cloud

    var body: some View {
        HStack(spacing: 8) {
            Circle().fill(color).frame(width: 10, height: 10)
            Text(title).font(.footnote)
            if cloud.syncStatus.isSyncing {
                ProgressView().controlSize(.mini)
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(.thinMaterial, in: Capsule())
    }

    private var color: Color {
        if !cloud.networkStatus.isConnected { return .gray   }
        if !cloud.accountStatus.isAvailable { return .orange }
        if cloud.syncStatus.hasError        { return .red    }
        if cloud.syncStatus.isSyncing       { return .blue   }
        return .green
    }

    private var title: String {
        switch cloud.syncStatus {
        case .idle:      return cloud.canSync ? "Synced" : "Offline"
        case .setup:     return "Preparing…"
        case .importing: return "Downloading…"
        case .exporting: return "Uploading…"
        case .error:     return "Sync error"
        }
    }
}
```

## Sign-in prompt (iOS only)

```swift
#if os(iOS)
struct SignInPrompt: View {
    @Environment(CloudSyncMonitor.self) private var cloud

    var body: some View {
        if !cloud.accountStatus.isAvailable {
            VStack(spacing: 12) {
                Text("Sign in to iCloud to enable sync.\n" +
                     "Settings → Apple ID → iCloud")
                    .multilineTextAlignment(.center)
                Button("Open Settings") {
                    SettingsLauncher.openAppSettings()
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
}
#endif
```

> **Note on deep links.** There is no public URL scheme that jumps straight
> to Settings → Apple ID → iCloud. Apple has removed private schemes from
> App Store review. Open the app's Settings page and instruct the user to
> navigate from there. On watchOS there is no programmatic settings link
> at all — `SettingsLauncher` is not compiled on that platform.

## Testing

Every monitor sits behind a protocol:

- `ICloudAccountMonitoring`
- `NetworkMonitoring`
- `ICloudDriveMonitoring`
- `CloudKitSyncMonitoring`

Provide mock implementations to drive the facade in unit tests:

```swift
final class MockAccountMonitor: ICloudAccountMonitoring {
    private let subject = CurrentValueSubject<ICloudAccountStatus, Never>(.available)
    var statusPublisher: AnyPublisher<ICloudAccountStatus, Never> {
        subject.eraseToAnyPublisher()
    }
    var currentStatus: ICloudAccountStatus { subject.value }
    func start() {}
    func stop()  {}
    func refresh() async {}
    func simulate(_ value: ICloudAccountStatus) { subject.send(value) }
}
```

## License

MIT.
