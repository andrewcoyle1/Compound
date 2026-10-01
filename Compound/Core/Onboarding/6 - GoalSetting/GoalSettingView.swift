//
//  GoalSettingView.swift
//  Compound
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
            onDevSettingsPressed: nil
        ) {
            Section {
                Text("Your goal generates a custom plan to get you there. This can be changed later, and your plan will update accordingly.")
                    .font(.rowDetail)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Goal")
            }
        }
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
