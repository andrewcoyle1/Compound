//
//  HealthDisclaimerRouter.swift
//  DialedIn
//
//  Created by Andrew Coyle on 27/11/2025.
//

@MainActor
protocol HealthDisclaimerRouter: GlobalRouter {
#if DEV || MOCK
func showDevSettingsView()
#endif
    func showGoalSettingView()
    func showHealthDisclaimerConfirmationModal(onConfirmPressed: @escaping () -> Void, onCancelPressed: @escaping () -> Void) 
}

extension CoreRouter: HealthDisclaimerRouter {
    
    func showHealthDisclaimerConfirmationModal(onConfirmPressed: @escaping () -> Void, onCancelPressed: @escaping () -> Void) {
        router.showModal(
            transition: .opacity,
            backgroundColor: .black.opacity(0.3),
            dismissOnBackgroundTap: true,
            destination: {
                CustomModalView(
                    title: String(localized: "Confirm and Continue"),
                    subtitle: """
                    By continuing, you confirm that:
                    • You have read and accept the Health Disclaimer.
                    • You have read and accept the Consumer Health Privacy Notice.

                    You understand DialedIn does not provide medical advice and is for educational use only. You can review these terms at any time in Settings.
                    """,
                    primaryButtonTitle: "I Agree & Continue",
                    primaryButtonAction: { onConfirmPressed() },
                    secondaryButtonTitle: "Go Back",
                    secondaryButtonAction: { onCancelPressed() }
                )
            }
        )
    }
}
