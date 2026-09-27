//
//  CustomPaywallViewTests.swift
//  DialedInUnitTests
//

import Testing
import SwiftUI
@testable import DialedIn

/// The custom paywall's buttons. The presenter behind them is covered in `PaywallPresenterTests`;
/// what is checked here is that the buttons actually reach it.
@MainActor
struct CustomPaywallViewTests {

    /// Restore Subscription's action was an empty closure, so the button did nothing.
    @Test("Test Restore Subscription Reaches The Restore Callback")
    func testRestoreSubscriptionReachesTheRestoreCallback() {
        var restoreCount = 0
        let view = CustomPaywallView(onRestorePurchasePressed: { restoreCount += 1 })

        view.restoreButton.action()

        #expect(restoreCount == 1)
    }
}
