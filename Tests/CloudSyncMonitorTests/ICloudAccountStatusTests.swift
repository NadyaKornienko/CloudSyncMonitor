//
//  ICloudAccountStatusTests.swift
//  CloudSyncMonitorTests
//
//  Created by Nadezhda Kornienko on 17/4/2026.
//

import CloudKit
import Testing

@testable import CloudSyncMonitor

@Suite("ICloudAccountStatus")
struct ICloudAccountStatusTests {

    @Test("Maps every CKAccountStatus case losslessly")
    func ckMapping() {
        #expect(ICloudAccountStatus(ckStatus: .available) == .available)
        #expect(ICloudAccountStatus(ckStatus: .noAccount) == .noAccount)
        #expect(ICloudAccountStatus(ckStatus: .restricted) == .restricted)
        #expect(
            ICloudAccountStatus(ckStatus: .couldNotDetermine)
                == .couldNotDetermine
        )
        #expect(
            ICloudAccountStatus(ckStatus: .temporarilyUnavailable)
                == .temporarilyUnavailable
        )
    }

    @Test("isAvailable is true only for .available")
    func isAvailableFlag() {
        #expect(ICloudAccountStatus.available.isAvailable)
        #expect(!ICloudAccountStatus.noAccount.isAvailable)
        #expect(!ICloudAccountStatus.restricted.isAvailable)
        #expect(!ICloudAccountStatus.couldNotDetermine.isAvailable)
        #expect(!ICloudAccountStatus.temporarilyUnavailable.isAvailable)
    }

    @Test("Debug description is non-empty for every case")
    func debugDescriptionIsNeverEmpty() {
        let all: [ICloudAccountStatus] = [
            .available, .noAccount, .restricted,
            .couldNotDetermine, .temporarilyUnavailable,
        ]
        for status in all {
            #expect(!status.debugDescription.isEmpty)
        }
    }
}
