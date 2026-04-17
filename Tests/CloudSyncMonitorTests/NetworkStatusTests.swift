//
//  NetworkStatusTests.swift
//  CloudSyncMonitorTests
//
//  Created by Nadezhda Kornienko on 17/4/2026.
//

import Testing

@testable import CloudSyncMonitor

@Suite("NetworkStatus")
struct NetworkStatusTests {

    @Test("`.disconnected` is fully offline")
    func disconnectedDefault() {
        let s = NetworkStatus.disconnected
        #expect(!s.isConnected)
        #expect(!s.isExpensive)
        #expect(!s.isConstrained)
        #expect(s.connectionType == .none)
    }

    @Test("Equatable compares every stored field")
    func equatable() {
        let a = NetworkStatus(
            isConnected: true,
            isExpensive: false,
            isConstrained: false,
            connectionType: .wifi
        )
        let b = NetworkStatus(
            isConnected: true,
            isExpensive: false,
            isConstrained: false,
            connectionType: .wifi
        )
        let c = NetworkStatus(
            isConnected: true,
            isExpensive: true,
            isConstrained: false,
            connectionType: .wifi
        )
        #expect(a == b)
        #expect(a != c)
    }
}
