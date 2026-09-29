//
//  GoalSettingView.swift
//  DialedIn
//
//  Created by Andrew Coyle on 05/10/2025.
//

import SwiftUI

struct GoalSettingView: View {

    @State var presenter: GoalSettingPresenter

    var body: some View {
        OnboardingStepScaffold(
            title: "Ready to Set a Goal?",
            progress: OnboardingStep.goalSetting.progress,
            primary: .init(title: "Continue", identifier: "Continue") { presenter.onContinuePressed() },
            onDevSettingsPressed: onDevSettingsPressed
        ) {
            Section {
                Text("Depending on what your goal is, we will help you by generating a custom plan to help you get there. This can be changed in future, and your plan will be updated accordingly.")
                    .font(.rowDetail)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Goal")
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
    func goalSettingView(router: AnyRouter) -> some View {
        GoalSettingView(
            presenter: GoalSettingPresenter(interactor: interactor, router: CoreRouter(router: router, builder: self))
        )
    }
}

extension CoreRouter {
    func showGoalSettingView() {
        router.showScreen(.push) { router in
            builder.goalSettingView(router: router)
        }
    }
}

#Preview {
    let builder = CoreBuilder(interactor: CoreInteractor(container: DevPreview.shared.container()))
    RouterView { router in
        builder.goalSettingView(router: router)
    }
    
}
