//
//  OnboardingHealthData.swift
//  DialedIn
//
//  Created by Andrew Coyle on 24/09/2025.
//

import SwiftUI

struct OnboardingHealthDataView: View {

    @State var presenter: OnboardingHealthDataPresenter

    var body: some View {
        OnboardingStepScaffold(
            title: "Connect Apple Health?",
            progress: OnboardingStep.healthData.progress,
            primary: .init(title: "Allow access to health data", identifier: "AllowAccessToHealthData") { presenter.onAllowAccessPressed() },
            secondary: .init(title: "Skip for now", identifier: "SkipForNow") { presenter.onSkipForNowPressed() },
            onDevSettingsPressed: onDevSettingsPressed
        ) {
            Section {
                OnboardingFeatureRow(
                    title: "Why We Request Health Data Access",
                    detail: "Compound needs permission to read and write your weight data in Apple Health. This allows us to automatically track your progress, update your weight logs, and provide you with accurate charts and insights.",
                    systemImage: Symbol.scaleWeight
                )
            } header: {
                Text("Your Health, Your Data")
            }
            Section {
                Label("Sync your weight entries seamlessly between Compound and Apple Health.", systemImage: "arrow.triangle.2.circlepath")
                Label("See all your progress in one place, even if you use other health apps.", systemImage: Symbol.analytics)
                Label("Let Compound update your Health data when you log new weights.", systemImage: "plus.circle")
            } header: {
                Text("What You Get")
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
            Section {
                Label("Maintain full control: you can revoke access or limit permissions at any time in the Health app.", systemImage: "lock.shield")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Your Control")
            }
        }
        .scrollIndicators(.hidden)
        .navigationBarBackButtonHidden(true)
        .onAppear {
            presenter.onViewAppear()
        }
        .onDisappear {
            presenter.onViewDisappear()
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
    func onboardingHealthDataView(router: AnyRouter) -> some View {
        OnboardingHealthDataView(
            presenter: OnboardingHealthDataPresenter(interactor: interactor, router: CoreRouter(router: router, builder: self))
        )
    }
}

extension CoreRouter {
    func showOnboardingHealthDataView() {
        router.showScreen(.push) { router in
            builder.onboardingHealthDataView(router: router)
        }
    }
}

#Preview("Proceed to Notifications") {
    let builder = CoreBuilder(interactor: CoreInteractor(container: DevPreview.shared.container()))
    RouterView { router in
        builder.onboardingHealthDataView(router: router)
    }
    
}
