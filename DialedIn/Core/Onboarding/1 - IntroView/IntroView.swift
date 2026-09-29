//
//  IntroView.swift
//  DialedIn
//
//  Created by Andrew Coyle on 13/08/2025.
//

import SwiftUI

struct IntroView: View {

    @State var presenter: IntroPresenter

    var body: some View {
        OnboardingStepScaffold(
            title: "Why Compound?",
            subtitle: "Welcome to Compound.",
            progress: OnboardingStep.auth.progress,
            primary: .init(title: "Continue", identifier: "Continue") { presenter.navigateToAuth() },
            onDevSettingsPressed: onDevSettingsPressed
        ) {
            feature(
                "Training",
                title: "Track Your Workouts",
                detail: "Log your strength and cardio sessions, follow expert routines, and visualize your progress over time. Stay motivated with streaks and personal bests.",
                systemImage: Symbol.workout
            )
            feature(
                "Nutrition",
                title: "Monitor Your Nutrition",
                detail: "Easily log meals, scan foods, and get AI-powered nutrition analysis. Set goals, track macros, and receive personalized recommendations to fuel your journey.",
                systemImage: Symbol.nutrition
            )
            feature(
                "Weight Tracking",
                title: "Track Your Weight",
                detail: "Log your weight over time and visualize your progress with interactive charts. Set goals, monitor trends, and stay accountable on your fitness journey.",
                systemImage: Symbol.scaleWeight
            )
        }
        #if !DEBUG && !MOCK
        .navigationBarBackButtonHidden(true)
        #endif
        .onAppear {
            presenter.onViewAppear()
        }
        .onDisappear {
            presenter.onViewDisappear()
        }
    }

    private func feature(_ header: LocalizedStringKey, title: LocalizedStringKey, detail: LocalizedStringKey, systemImage: String) -> some View {
        Section {
            OnboardingFeatureRow(title: title, detail: detail, systemImage: systemImage)
        } header: {
            Text(header)
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
    func introView(router: AnyRouter) -> some View {
        IntroView(
            presenter: IntroPresenter(interactor: interactor, router: CoreRouter(router: router, builder: self))
        )
        
    }
}

extension CoreRouter {
    func showIntroView() {
        router.showScreen(.push) { router in
            builder.introView(router: router)
        }
    }
}

#Preview {
    let builder = CoreBuilder(interactor: CoreInteractor(container: DevPreview.shared.container()))
    RouterView { router in
        builder.introView(router: router)
    }
    
}
