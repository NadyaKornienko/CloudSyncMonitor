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
| iOS       | 17.0            |
| watchOS   | 10.0            |
| macOS     | 14.0            |
| tvOS      | 17.0            |
| visionOS  | 1.0             |
| Swift     | 6.0             |

## Installation (Swift Package Manager)

In Xcode: **File → Add Package Dependencies…** and paste the repository URL.

Or, in `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/NadyaKornienko/CloudSyncMonitor.git", from: "2.1.0")
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

## Configuration

`CloudSyncMonitor` exposes key configuration options via its initializer. All underlying monitors are injected via protocols, making it easy to swap them for mocks in tests:

- **`isDriveCheckEnabled`** (default: `false`)
  Controls whether iCloud Drive availability affects the derived `state` and `canSync` flag. 
  - Set to `true` if your app syncs user documents via iCloud Drive. 
  - Leave as `false` (default) for pure CloudKit / Core Data + CloudKit apps that don't rely on `FileManager.ubiquityIdentityToken`.

- **`userDefaults`** (default: `.standard`)
  The backing store for persisted flags (`hasCompletedInitialSync`, `lastSyncDate`). 
  Inject a custom suite in tests to keep them hermetic and prevent state leaking between test runs.

```swift
let syncMonitor = CloudSyncMonitor(
    isDriveCheckEnabled: true, // If your app uses iCloud Drive
    userDefaults: .standard    // Or a custom suite for tests
)
```

## Quick start

```swift
import SwiftUI
import CloudSyncMonitor

@main
struct MyApp: App {
    @State private var syncMonitor = CloudSyncMonitor()
    let persistence = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.managedObjectContext,
                             persistence.container.viewContext)
                .cloudSyncMonitor(syncMonitor)
        }
    }
}

struct CloudStatusBadge: View {
    @Environment(CloudSyncMonitor.self) private var syncMonitor

    var body: some View {
        HStack(spacing: 8) {
            Circle().fill(color).frame(width: 10, height: 10)
            Text(title).font(.footnote)
            if syncMonitor.syncStatus.isSyncing {
                ProgressView().controlSize(.mini)
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(.thinMaterial, in: Capsule())
    }

    private var color: Color {
        if !syncMonitor.networkStatus.isConnected { return .gray   }
        if !syncMonitor.accountStatus.isAvailable { return .orange }
        if syncMonitor.syncStatus.hasError        { return .red    }
        if syncMonitor.syncStatus.isSyncing       { return .blue   }
        return .green
    }

    private var title: String {
        // Uses built-in localization (24 languages)
        syncMonitor.syncStatus.localizedDescription
    }
}
```
> [!TIP]
> This example uses `cloud.syncStatus.localizedDescription` for automatic localization in 24 languages. See the [Localization](#localization) section if you prefer to override strings with your own design.

> [!IMPORTANT]
> Apply the `.cloudSyncMonitor()` modifier to your **root view** (typically inside `WindowGroup`). If you apply it to a child view or a specific tab, the monitor will stop tracking sync events when that view disappears from the screen. For granular lifecycle control (e.g., stopping when the app goes to the background), use `autoStart: false` and manage `start()`/`stop()` manually via `@Environment(\.scenePhase)`.

## Manual Lifecycle (Non-SwiftUI or Advanced Usage)

If you are not using the `.cloudSyncMonitor()` SwiftUI view modifier, or if you need to tie the monitor's lifecycle to something other than a View's appearance (e.g., in an `AppDelegate`, a UIKit/AppKit app, or a specific ViewModel), you must call `start()` and `stop()` manually:

```swift
let syncMonitor = CloudSyncMonitor()

// When your app becomes active / view appears
syncMonitor.start()

// When your app goes to background / view disappears (optional, but saves battery)
syncMonitor.stop()
```
> [!NOTE] 
> `start()` is idempotent. Calling it multiple times is safe and will not create duplicate subscriptions.

## Sign-in prompt (iOS only)

```swift
#if os(iOS)
struct SignInPrompt: View {
    @Environment(CloudSyncMonitor.self) private var syncMonitor

    var body: some View {
        if !syncMonitor.accountStatus.isAvailable {
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

> [!NOTE]
> There is no public URL scheme that jumps straight
> to Settings → Apple ID → iCloud. Apple has removed private schemes from
> App Store review. Open the app's Settings page and instruct the user to
> navigate from there. On watchOS there is no programmatic settings link
> at all — `SettingsLauncher` is not compiled on that platform.

## Localization

CloudSyncMonitor provides built‑in localization for all user‑facing status messages in **24 languages**.

The library automatically uses the device's preferred language and falls back to English when a language isn't supported.

### Supported languages

| Language              | Locale   | Language              | Locale   |
|-----------------------|----------|-----------------------|----------|
| Catalan               | `ca`     | Italian               | `it`     |
| Chinese (Simplified)  | `zh-Hans`| Japanese              | `ja`     |
| Chinese (Traditional) | `zh-Hant`| Korean                | `ko`     |
| Danish                | `da`     | Polish                | `pl`     |
| Dutch                 | `nl`     | Portuguese (Brazil)   | `pt-BR`  |
| English               | `en`     | Portuguese (Portugal) | `pt-PT`  |
| English (US)          | `en-US`  | Russian               | `ru`     |
| Filipino              | `fil`    | Spanish               | `es`     |
| Finnish               | `fi`     | Spanish (Latin Am.)   | `es-419` |
| French                | `fr`     | Swedish               | `sv`     |
| French (Canada)       | `fr-CA`  | Turkish               | `tr`     |
| German                | `de`     | Ukrainian             | `uk`     |

### Regional variants

- **`fr-CA`** — Canadian French (e.g., `téléversement` vs `envoi`)
- **`pt-PT`** — European Portuguese (`Definições`, `A transferir`)
- **`es-419`** — Neutral Latin American Spanish (`Ajustes`, `ID de Apple`)

### Overriding default strings

The library remains **headless** — you control your UI. You can ignore the built‑in localization and provide your own strings.
The recommended approach is to switch on the aggregated `state` property, which already accounts for network, account, and drive issues:

```swift
var title: String {
    // Complete override — use your own strings and design
    switch syncMonitor.state {
    case .ok:               return "✅ Synced"
    case .initialSync:      return "🔧 Setting up…"
    case .syncing:          return "🔄 Syncing…"
    case .offline:          return "📡 Offline"
    case .signedOut:        return "👤 Sign in required"
    case .driveDisabled:    return "📁 Drive disabled"
    case .notSyncing:       return "⚠️ Not syncing"
    case .failed:           return "❌ Sync error"
    }
}
```
> [!TIP]
> If you only care about the raw CloudKit engine status (ignoring network/account), you can use `syncMonitor.syncStatus.localizedDescription`.

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

### Isolating tests with custom `UserDefaults`

Because `CloudSyncMonitor` persists flags like `hasCompletedInitialSync` across app launches, tests can leak state into each other if they share `UserDefaults.standard`. Inject an isolated suite to keep tests hermetic:

```swift
func testInitialSyncFlag() async {
    let suiteName = "CloudSyncMonitor.tests.\(UUID().uuidString)"
    let isolatedDefaults = UserDefaults(suiteName: suiteName)!
    isolatedDefaults.removePersistentDomain(forName: suiteName)

    let syncMonitor = CloudSyncMonitor(
        accountMonitor: MockAccountMonitor(),
        networkMonitor: MockNetworkMonitor(),
        driveMonitor: MockDriveMonitor(),
        syncMonitor: MockSyncMonitor(),
        userDefaults: isolatedDefaults
    )
    
    // Test logic here...
}
```

## License

MIT.
