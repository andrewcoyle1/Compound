//
//  ProteinIntakeView.swift
//  Compound
//
//  Created by Andrew Coyle on 06/10/2025.
//

import SwiftUI

struct ProteinIntakeDelegate {
    let preferredDiet: PreferredDiet
    let calorieFloor: CalorieFloor
    let calorieDistrubtion: CalorieDistribution
    var isFromSettings: Bool

    init(delegate: CalorieDistributionDelegate, calorieDistribution: CalorieDistribution) {
        self.preferredDiet = delegate.preferredDiet
        self.calorieFloor = delegate.calorieFloor
        self.calorieDistrubtion = calorieDistribution
        self.isFromSettings = delegate.isFromSettings
    }
    
    static var mock: Self {
        Self(delegate: .mock, calorieDistribution: .even)
    }
}

struct ProteinIntakeView: View {

    @State var presenter: ProteinIntakePresenter

    var delegate: ProteinIntakeDelegate

    var body: some View {
        OnboardingStepScaffold(
            title: "How Much Protein?",
            progress: delegate.isFromSettings ? nil : OnboardingStep.customiseProgram.progress,
            primary: .init(title: "Continue", isEnabled: presenter.selectedProteinIntake != nil, identifier: "Continue") { presenter.onContinuePressed(delegate: delegate) },
            onDevSettingsPressed: nil
        ) {
            Section {
                ForEach(ProteinIntake.allCases) { intake in
                    SelectableRow(title: intake.description, subtitle: intake.detailedDescription, isSelected: presenter.selectedProteinIntake == intake) {
                        presenter.onProteinIntakeSelected(intake)
                    }
                }
            } header: {
                MethodInfoHeader(title: "Protein", info: .proteinTarget)
            } footer: {
                Text("Worked out on your body weight, or on the weight at a BMI of 30 if you're above it. If you have kidney disease, ask your doctor before eating more protein.")
            }
        }
        .onAppear { presenter.onViewAppear(isFromSettings: delegate.isFromSettings) }
        .onDisappear { presenter.onViewDisappear(isFromSettings: delegate.isFromSettings) }
    }

}

extension CoreBuilder {
    func proteinIntakeView(router: AnyRouter, delegate: ProteinIntakeDelegate) -> some View {
        ProteinIntakeView(
            presenter: ProteinIntakePresenter(interactor: interactor, router: CoreRouter(router: router, builder: self)),
            delegate: delegate
        )
    }
}

extension CoreRouter {
    func showProteinIntakeView(delegate: ProteinIntakeDelegate) {
        router.showScreen(.push) { router in
            builder.proteinIntakeView(router: router, delegate: delegate)
        }
    }
}

#Preview {
    let builder = CoreBuilder(interactor: CoreInteractor(container: DevPreview.shared.container()))
    RouterView { router in
        builder.proteinIntakeView(
            router: router,
            delegate: .mock
        )
    }
    
}
