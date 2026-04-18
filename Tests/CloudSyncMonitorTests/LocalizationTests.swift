//
//  LocalizationTests.swift
//  CloudSyncMonitor
//
//  Created by Nadezhda Kornienko on 18/4/2026.
//

//
//  Sanity checks: every public value must resolve to a non-empty
//  localized description. This guards against missing keys
//  and accidental empty translations.
//

import Testing

@testable import CloudSyncMonitor

@Suite("Localization")
struct LocalizationTests {

    @Test(
        "Every ICloudAccountStatus case has a non-empty localized description"
    )
    func accountStatusStrings() {
        let all: [ICloudAccountStatus] = [
            .available, .noAccount, .restricted,
            .couldNotDetermine, .temporarilyUnavailable,
        ]
        for value in all {
            #expect(!value.localizedDescription.isEmpty)
        }
    }

    @Test("Every ICloudDriveStatus case has a non-empty localized description")
    func driveStatusStrings() {
        for value in [ICloudDriveStatus.available, .unavailable] {
            #expect(!value.localizedDescription.isEmpty)
        }
    }

    @Test("Every CloudKitSyncStatus case has a non-empty localized description")
    func syncStatusStrings() {
        let all: [CloudKitSyncStatus] = [
            .idle, .setup, .importing, .exporting, .error(message: "x"),
        ]
        for value in all {
            #expect(!value.localizedDescription.isEmpty)
        }
    }

    @Test("Every EventType has a non-empty localized title")
    func eventTypeStrings() {
        for value in [CloudKitSyncEvent.EventType.setup, .import, .export] {
            #expect(!value.localizedTitle.isEmpty)
        }
    }

    @Test(
        "NetworkStatus localized description covers connected and offline paths"
    )
    func networkStatusStrings() {
        let wifi = NetworkStatus(
            isConnected: true,
            isExpensive: false,
            isConstrained: false,
            connectionType: .wifi
        )
        #expect(!wifi.localizedDescription.isEmpty)
        #expect(!NetworkStatus.disconnected.localizedDescription.isEmpty)
    }
}
