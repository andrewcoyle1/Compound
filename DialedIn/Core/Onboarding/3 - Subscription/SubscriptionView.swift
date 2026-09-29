//
//  SubscriptionView.swift
//  DialedIn
//
//  Created by Andrew Coyle on 04/10/2025.
//

import SwiftUI

struct SubscriptionView: View {

    @State var presenter: SubscriptionPresenter

    var body: some View {
        OnboardingStepScaffold(
            title: "Why Subscribe?",
            subtitle: "A subscription is required to use Compound.",
            progress: OnboardingStep.subscription.progress,
            primary: .init(title: "Continue", identifier: "Continue") { presenter.onContinuePressed() },
            // The way out for someone who will not subscribe.
            secondary: .init(title: "Sign Out", identifier: "SignOut") { presenter.onSignOutPressed() },
            onDevSettingsPressed: onDevSettingsPressed
        ) {
            Section {
                SubscriptionFeatureRows()
            }

            Section {
                ListRowButton(title: String(localized: "Account"), systemImage: Symbol.profile) {
                    presenter.onAccountPressed()
                }
            } footer: {
                Text("Edit, sign out of or delete your account without subscribing.")
            }
        }
        .navigationBarBackButtonHidden()
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
    func subscriptionView(router: AnyRouter) -> some View {
        SubscriptionView(
            presenter: SubscriptionPresenter(interactor: interactor, router: CoreRouter(router: router, builder: self))
        )
    }
}

extension CoreRouter {
    func showSubscriptionView() {
        router.showScreen(.push) { router in
            builder.subscriptionView(router: router)
        }
    }
}

#Preview {
    let builder = CoreBuilder(interactor: CoreInteractor(container: DevPreview.shared.container()))
    RouterView { router in
        builder.subscriptionView(router: router)
    }
    
}
