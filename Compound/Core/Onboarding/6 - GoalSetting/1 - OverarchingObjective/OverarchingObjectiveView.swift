//
//  OverarchingObjectiveView.swift
//  Compound
//
//  Created by Andrew Coyle on 05/10/2025.
//

import SwiftUI

struct OverarchingObjectiveView: View {

    @State var presenter: OverarchingObjectivePresenter

    var body: some View {
        OnboardingStepScaffold(
            title: "What Is Your Goal?",
            // In onboarding this carries the sentence the removed "Ready to Set a Goal?" screen held.
            subtitle: presenter.isStandaloneMode
                ? "Choose one"
                : "Your goal generates a custom plan to get you there. This can be changed later, and your plan will update accordingly.",
            progress: presenter.isStandaloneMode ? nil : OnboardingStep.goalSetting.progress,
            primary: .init(title: "Continue", isEnabled: presenter.canContinue, identifier: "Continue") { presenter.onContinuePressed() },
            onDevSettingsPressed: nil
        ) {
            Section {
                ForEach(OverarchingObjective.allCases, id: \.self) { objective in
                    SelectableRow(title: objective.description, subtitle: objective.detailedDescription, isSelected: presenter.selectedObjective == objective) {
                        presenter.onObjectiveSelected(objective)
                    }
                }
            }
        }
        .toolbar {
            if presenter.isStandaloneMode {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) { presenter.onDismissPressed() }
                }
            }
        }
        .onAppear { presenter.onViewAppear() }
        .onDisappear { presenter.onViewDisappear() }
    }

}

extension CoreBuilder {
    func overarchingObjectiveView(router: AnyRouter, isStandaloneMode: Bool = false, editingGoal: WeightGoal? = nil) -> some View {
        OverarchingObjectiveView(
            presenter: OverarchingObjectivePresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self),
                isStandaloneMode: isStandaloneMode,
                editingGoal: editingGoal
            )
        )
    }
}

extension CoreRouter {
    func showOverarchingObjectiveView() {
        router.showScreen(.push) { router in
            builder.overarchingObjectiveView(router: router)
        }
    }

    /// Setting or replacing the weight goal after onboarding, from Profile or Goal Progress.
    /// Sets a new goal, or edits `editing` when given.
    func showWeightGoalFlow(editing: WeightGoal?) {
        router.showScreen(.sheet) { router in
            builder.overarchingObjectiveView(router: router, isStandaloneMode: true, editingGoal: editing)
        }
    }

}

#Preview {
    let builder = CoreBuilder(interactor: CoreInteractor(container: DevPreview.shared.container()))
    RouterView { router in
        builder.overarchingObjectiveView(router: router)
    }
    
}
