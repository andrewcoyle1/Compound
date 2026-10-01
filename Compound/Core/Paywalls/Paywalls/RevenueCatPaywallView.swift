//
//  RevenueCatPaywallView.swift
//  AIChatCourse
//
//  Created by Nick Sarno on 11/2/24.
//
import SwiftUI
import RevenueCat
import RevenueCatUI

struct RevenueCatPaywallView: View {

    var displayCloseButton: Bool = true
    /// Each is passed whether the user now has an active entitlement.
    var onPurchaseCompleted: @MainActor (Bool) -> Void = { _ in }
    var onRestoreCompleted: @MainActor (Bool) -> Void = { _ in }

    var body: some View {
        RevenueCatUI.PaywallView(displayCloseButton: displayCloseButton)
            .onPurchaseCompleted { customerInfo in
                onPurchaseCompleted(!customerInfo.entitlements.active.isEmpty)
            }
            .onRestoreCompleted { customerInfo in
                onRestoreCompleted(!customerInfo.entitlements.active.isEmpty)
            }
            // Left alone, RevenueCat dismisses itself after a purchase. Pushed during onboarding,
            // that popped back to the previous step; the presenter decides where a purchase lands.
            .onRequestedDismissal { }
    }
}

#Preview {
    RevenueCatPaywallView()
}
