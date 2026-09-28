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
            progress: OnboardingStep.subscription.progress,
            primary: .init(title: "Continue", identifier: "Continue") { presenter.onContinuePressed() },
            onDevSettingsPressed: onDevSettingsPressed
        ) {
            Section {
                OnboardingFeatureRow(title: "Personalized plans", detail: "Training and nutrition tailored to your goals and schedule.", systemImage: Symbol.program)
                OnboardingFeatureRow(title: "Smart coaching", detail: "Daily guidance powered by your data and AI insights.", systemImage: Symbol.knowledgeBase)
                OnboardingFeatureRow(title: "Progress tracking", detail: "See trends, weekly summaries, and PRs at a glance.", systemImage: Symbol.analytics)
                OnboardingFeatureRow(title: "HealthKit sync", detail: "Automatically log workouts and recovery from Apple Health.", systemImage: "heart.circle")
                OnboardingFeatureRow(title: "Accountability", detail: "Reminders and nudges to help you stay consistent.", systemImage: Symbol.notifications)
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
