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

    var body: some View {
        RevenueCatUI.PaywallView(displayCloseButton: displayCloseButton)
    }
}

#Preview {
    RevenueCatPaywallView()
}
