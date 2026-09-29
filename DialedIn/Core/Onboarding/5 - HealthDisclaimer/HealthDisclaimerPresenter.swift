//
//  HealthDisclaimerPresenter.swift
//  DialedIn
//
//  Created by Andrew Coyle on 28/10/2025.
//

import SwiftUI

@Observable
@MainActor
class HealthDisclaimerPresenter {
    private let interactor: HealthDisclaimerInteractor
    private let router: HealthDisclaimerRouter

    var acceptedTerms: Bool = false
    var acceptedPrivacy: Bool = false

    var canContinue: Bool { acceptedTerms && acceptedPrivacy }
        
    // The wording of the legal text itself and its links are waiting on a decision (finding 2);
    // this only fixes the name and localizes what was a plain, unlocalized `String`.
    var disclaimerString: String = String(localized: """
            Compound is not a medical device and does not provide medical advice. The information presented is for general educational purposes only and is not a substitute for professional medical advice, diagnosis, or treatment.
            Always consult a qualified healthcare provider before starting any diet, exercise, or weight‑loss program, changing medications, or if you have questions about a medical condition.
            If you experience chest pain, shortness of breath, dizziness, or other concerning symptoms, stop activity and seek medical attention immediately. If you believe you may be experiencing a medical emergency, call your local emergency number right away.
            """)
    
    init(
        interactor: HealthDisclaimerInteractor,
        router: HealthDisclaimerRouter
    ) {
        self.interactor = interactor
        self.router = router
    }
    
    /// Two toggles and Continue record the choice. A confirmation alert that repeated both
    /// statements used to follow, making consent four presses; the owner dropped it (decision 2a).
    /// The consent recorded is unchanged: both version stamps, as before.
    func onContinuePressed() {
        guard canContinue else { return }
        router.showLoadingModal()

        // Recorded against the versions `inferredOnboardingStep` checks, so the two cannot drift.
        let disclaimerVersion = UserModel.currentHealthDisclaimerVersion
        let privacyVersion = UserModel.currentHealthPrivacyPolicyVersion
        let now = Date()
        interactor.trackEvent(event: Event.consentHealthConfirmStart(disclaimerVersion: disclaimerVersion, privacyVersion: privacyVersion))
        Task {
            do {
                try await interactor.updateHealthConsents(disclaimerVersion: disclaimerVersion, privacyVersion: privacyVersion, acceptedAt: now)
                interactor.trackEvent(event: Event.consentHealthConfirmSuccess(disclaimerVersion: disclaimerVersion, privacyVersion: privacyVersion, acceptedAt: now))
                
                router.dismissModal()
                handleNavigation()
            } catch {
                interactor.trackEvent(event: Event.consentHealthConfirmFail(disclaimerVersion: disclaimerVersion, privacyVersion: privacyVersion, error: error))
                
                router.dismissModal()
                router.showSimpleAlert(
                    title: String(localized: "Unable to Save Consent"),
                    subtitle: String(localized: "Please check your internet connection and try again.")
                )
            }
        }
    }

    func handleNavigation() {
        interactor.trackEvent(event: Event.navigate)
        router.showGoalSettingView()
    }

#if DEV || MOCK
func onDevSettingsPressed() {
    router.showDevSettingsView()
}
#endif

    enum Event: LoggableEvent {
        case consentHealthConfirmStart(disclaimerVersion: String, privacyVersion: String)
        case consentHealthConfirmSuccess(disclaimerVersion: String, privacyVersion: String, acceptedAt: Date)
        case consentHealthConfirmFail(disclaimerVersion: String, privacyVersion: String, error: Error)
        case navigate

        var eventName: String {
            switch self {
            case .consentHealthConfirmStart:    return "consent_health_confirm_start"
            case .consentHealthConfirmSuccess:  return "consent_health_confirm_success"
            case .consentHealthConfirmFail:     return "consent_health_confirm_fail"
            case .navigate:                     return "HealthDisclaimer_Navigate"
            }
        }
        
        var parameters: [String: Any]? {
            switch self {
            case .consentHealthConfirmStart(disclaimerVersion: let disclaimerVersion, privacyVersion: let privacyVersion):
                return [
                    "disclaimer_version": disclaimerVersion,
                    "privacy_version": privacyVersion
                ]
            case .consentHealthConfirmSuccess(disclaimerVersion: let disclaimerVersion, privacyVersion: let privacyVersion, acceptedAt: let acceptedAt):
                return [
                    "disclaimer_version": disclaimerVersion,
                    "privacy_version": privacyVersion,
                    "accepted_at": acceptedAt
                ]
            case .consentHealthConfirmFail(disclaimerVersion: let disclaimerVersion, privacyVersion: let privacyVersion, error: let error):
                var dict: [String: Any] = [
                    "disclaimer_version": disclaimerVersion,
                    "privacy_version": privacyVersion
                ]
                
                for (key, value) in error.eventParameters { dict[key] = value }
                return dict
            default: return nil
            }
        }
        
        var type: LogType {
            switch self {
            case .consentHealthConfirmFail:
                return .severe
            case .navigate:
                return .info
            default:
                return .analytic
                
            }
        }
    }
}
