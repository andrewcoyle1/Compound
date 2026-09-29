//
//  HealthDisclaimerView.swift
//  DialedIn
//
//  Created by Andrew Coyle on 05/10/2025.
//

import SwiftUI

struct HealthDisclaimerView: View {

    @State var presenter: HealthDisclaimerPresenter

    var body: some View {
        OnboardingStepScaffold(
            title: "Do You Agree?",
            progress: OnboardingStep.healthDisclaimer.progress,
            primary: .init(title: "Continue", isEnabled: presenter.canContinue, identifier: "Continue") { presenter.onContinuePressed() },
            onDevSettingsPressed: onDevSettingsPressed
        ) {
            Section {
                Text(presenter.disclaimerString)
            } header: {
                Text("Health Disclaimer")
            }
            Section {
                Toggle(isOn: $presenter.acceptedTerms) {
                    Text("I acknowledge and accept the Terms of the Health Disclaimer")
                }
                .accessibilityIdentifier("HealthDisclaimerToggle")
                documentLink(.healthDisclaimer)
            }
            Section {
                Toggle(isOn: $presenter.acceptedPrivacy) {
                    Text("I acknowledge and accept the Terms of the Consumer Health Privacy Notice")
                }
                .accessibilityIdentifier("HealthPrivacyPolicyToggle")
                documentLink(.consumerHealthPrivacy)
            }
        }
        .scrollIndicators(.hidden)
    }

    /// The document a toggle accepts, one row under it, so nobody is asked to accept a text the
    /// screen does not let them read. Same row shape as Profile's Legal list.
    @ViewBuilder
    private func documentLink(_ document: LegalDocument) -> some View {
        if let url = document.url {
            Link(destination: url) {
                ListRow(title: document.title, accessory: .custom(AnyView(
                    Image(systemName: "arrow.up.right")
                        .font(.label)
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                )))
            }
            .accessibilityHint("Opens in your browser")
        }
    }

    private var onDevSettingsPressed: (() -> Void)? {
        #if DEV || MOCK
        presenter.onDevSettingsPressed
        #else
        nil
        #endif
    }
}

extension CoreBuilder {
    func healthDisclaimerView(router: AnyRouter) -> some View {
        HealthDisclaimerView(
            presenter: HealthDisclaimerPresenter(interactor: interactor, router: CoreRouter(router: router, builder: self))
        )
    }
}

extension CoreRouter {
    func showHealthDisclaimerView() {
        router.showScreen(.push) { router in
            builder.healthDisclaimerView(router: router)
        }
    }

}

#Preview("Health Disclaimer") {
    let builder = CoreBuilder(interactor: CoreInteractor(container: DevPreview.shared.container()))
    RouterView { router in
        builder.healthDisclaimerView(router: router)
    }
    
}
