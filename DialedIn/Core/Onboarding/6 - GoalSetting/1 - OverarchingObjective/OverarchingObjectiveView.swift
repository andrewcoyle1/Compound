//
//  OverarchingObjectiveView.swift
//  DialedIn
//
//  Created by Andrew Coyle on 05/10/2025.
//

import SwiftUI

struct OverarchingObjectiveView: View {

    @State var presenter: OverarchingObjectivePresenter

    var body: some View {
        OnboardingStepScaffold(
            title: "What Is Your Goal?",
            subtitle: "Choose one",
            progress: presenter.isStandaloneMode ? nil : OnboardingStep.goalSetting.progress,
            primary: .init(title: "Continue", isEnabled: presenter.canContinue, identifier: "Continue") { presenter.onContinuePressed() },
            onDevSettingsPressed: onDevSettingsPressed
        ) {
            Section {
                ForEach(OverarchingObjective.allCases, id: \.self) { objective in
                    SelectableRow(title: objective.description, subtitle: objective.detailedDescription, isSelected: presenter.selectedObjective == objective) {
                        presenter.onObjectiveSelected(objective)
                    }
                }
            }
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
    func overarchingObjectiveView(router: AnyRouter) -> some View {
        OverarchingObjectiveView(
            presenter: OverarchingObjectivePresenter(interactor: interactor, router: CoreRouter(router: router, builder: self))
        )
    }
}

extension CoreRouter {
    func showOverarchingObjectiveView() {
        router.showScreen(.push) { router in
            builder.overarchingObjectiveView(router: router)
        }
    }

}

#Preview {
    let builder = CoreBuilder(interactor: CoreInteractor(container: DevPreview.shared.container()))
    RouterView { router in
        builder.overarchingObjectiveView(router: router)
    }
    
}
