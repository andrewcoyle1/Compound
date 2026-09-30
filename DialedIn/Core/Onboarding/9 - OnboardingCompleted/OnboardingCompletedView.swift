//
//  OnboardingCompletedView.swift
//  DialedIn
//
//  Created by Andrew Coyle on 13/08/2025.
//

import SwiftUI

struct OnboardingCompletedView: View {

    @State var presenter: OnboardingCompletedPresenter

    var body: some View {
        VStack(spacing: Spacing.s) {
            Image(systemName: "rectangle.stack.fill.badge.plus")
                .iconSize(.hero)
                .foregroundStyle(.tint)
                .padding(.bottom, Spacing.s)
                .accessibilityHidden(true)
            Text("Onboarding Complete!")
                .font(.display)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            Text("You're ready to start compounding.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.canvas.ignoresSafeArea())
        .bottomCTA {
            CallToActionButton(isLoading: presenter.isCompletingProfileSetup) {
                presenter.onFinishButtonPressed()
            } label: {
                Text("Continue")
            }
            .accessibilityIdentifier("Continue")
        }
        #if !DEBUG && !MOCK
        .navigationBarBackButtonHidden(true)
        #endif
    }
}

extension CoreBuilder {
    func onboardingCompletedView(router: AnyRouter) -> some View {
        OnboardingCompletedView(
            presenter: OnboardingCompletedPresenter(interactor: interactor, router: CoreRouter(router: router, builder: self))
        )
    }
}

extension CoreRouter {
    func showOnboardingCompletedView() {
        router.showScreen(.push) { router in
            builder.onboardingCompletedView(router: router)
        }
    }
}

#Preview {
    let builder = CoreBuilder(interactor: CoreInteractor(container: DevPreview.shared.container()))
    RouterView { router in
        builder.onboardingCompletedView(router: router)
    }
    
}
