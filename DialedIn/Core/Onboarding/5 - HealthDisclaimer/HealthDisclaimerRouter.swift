//
//  HealthDisclaimerRouter.swift
//  DialedIn
//
//  Created by Andrew Coyle on 27/11/2025.
//

import SwiftUI

@MainActor
protocol HealthDisclaimerRouter: GlobalRouter {
#if DEV || MOCK
func showDevSettingsView()
#endif
    func showGoalSettingView()
    func showHealthDisclaimerConfirmationModal(onConfirmPressed: @escaping @Sendable () -> Void, onCancelPressed: @escaping @Sendable () -> Void)
}

extension CoreRouter: HealthDisclaimerRouter {

    func showHealthDisclaimerConfirmationModal(onConfirmPressed: @escaping @Sendable () -> Void, onCancelPressed: @escaping @Sendable () -> Void) {
        let subtitle = String(localized: """
        By continuing, you confirm that:
        • You have read and accept the Health Disclaimer.
        • You have read and accept the Consumer Health Privacy Notice.

        You understand Compound does not provide medical advice and is for educational use only. You can review these terms at any time in Settings.
        """)
        showAlert(
            title: String(localized: "Confirm and Continue"),
            subtitle: subtitle,
            buttons: {
                AnyView(VStack {
                    Button(String(localized: "I Agree & Continue")) { onConfirmPressed() }
                    Button(String(localized: "Go Back"), role: .cancel) { onCancelPressed() }
                })
            }
        )
    }
}
