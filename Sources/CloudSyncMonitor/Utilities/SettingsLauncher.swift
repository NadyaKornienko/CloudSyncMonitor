//
//  SettingsLauncher.swift
//  CloudSyncMonitor
//
//  Created by Nadezhda Kornienko on 17/4/2026.
//

//  A tiny, platform-aware helper to send the user to the Settings app.
//
//  IMPORTANT — App Store compliance
//  ================================
//  Apple does NOT provide a public URL scheme that deep-links into a
//  specific Settings panel (such as "Apple ID → iCloud"). The private
//  `App-Prefs:` / `prefs:root=...` schemes are **not** allowed and will
//  result in App Store rejection. The best publicly-sanctioned behaviour
//  is to open the app's own Settings page via
//  `UIApplication.openSettingsURLString` and instruct the user to
//  navigate to "Apple ID → iCloud" themselves.
//
//  watchOS
//  =======
//  `UIApplication` is not available on watchOS. On that platform users
//  must manage iCloud from the companion iPhone or from the watch's own
//  Settings app; no programmatic deep link exists. `SettingsLauncher` is
//  therefore compiled only where `UIApplication` is available.
//

#if canImport(UIKit) && !os(watchOS) && !os(tvOS)
    import UIKit

    /// Helpers for bringing the user to the system Settings app.
    public enum SettingsLauncher {

        /// Opens the current application's page inside the Settings app.
        ///
        /// - Returns: `true` if the URL was accepted by the system and the
        ///   Settings app was launched, `false` otherwise.
        ///
        /// - Important: This does **not** jump to the iCloud panel — Apple
        ///   no longer permits deep links into system panes. Accompany the
        ///   button with a short hint such as
        ///   *"Open Settings → Apple ID → iCloud to sign in."*
        @MainActor
        @discardableResult
        public static func openAppSettings() -> Bool {
            guard
                let url = URL(string: UIApplication.openSettingsURLString),
                UIApplication.shared.canOpenURL(url)
            else { return false }
            UIApplication.shared.open(url)
            return true
        }
    }
#endif  // canImport(UIKit) && !os(watchOS) && !os(tvOS)
