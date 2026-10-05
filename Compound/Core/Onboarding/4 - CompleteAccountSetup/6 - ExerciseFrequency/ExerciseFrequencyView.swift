//
//  ExerciseFrequencyView.swift
//  Compound
//
//  Created by Andrew Coyle on 04/10/2025.
//

import SwiftUI

struct ExerciseFrequencyDelegate {
    let gender: Gender
    let dateOfBirth: Date
    let heightInCentimetres: Double
    let lengthUnitPreference: LengthUnitPreference
    let weightInKilograms: Double
    let weightUnitPreference: WeightUnitPreference
    
    init(delegate: WeightDelegate, weightInKilograms: Double, weightUnitPreference: WeightUnitPreference) {
        self.gender = delegate.gender
        self.dateOfBirth = delegate.dateOfBirth
        self.heightInCentimetres = delegate.heightInCentimeters
        self.lengthUnitPreference = delegate.lengthUnitPreference
        self.weightInKilograms = weightInKilograms
        self.weightUnitPreference = weightUnitPreference
    }
    
    static var mock: Self {
        Self(delegate: .mock, weightInKilograms: 82, weightUnitPreference: .kilograms)
    }
}

struct ExerciseFrequencyView: View {

    @State var presenter: ExerciseFrequencyPresenter

    var delegate: ExerciseFrequencyDelegate

    var body: some View {
        OnboardingStepScaffold(
            title: "Do You Work Out?",
            subtitle: "How often you exercise feeds the calorie estimate. You can change it later in Profile.",
            progress: OnboardingStep.completeAccountSetup.progress,
            primary: .init(title: "Continue", isEnabled: presenter.canSubmit, identifier: "Continue") { presenter.onContinuePressed(delegate: delegate) },
            onDevSettingsPressed: nil
        ) {
            Section {
                ForEach(ExerciseFrequency.allCases, id: \.self) { frequency in
                    SelectableRow(title: frequency.description, isSelected: presenter.selectedFrequency == frequency) {
                        presenter.onFrequencySelected(frequency)
                    }
                }
            }
        }
        .onAppear { presenter.onViewAppear() }
        .onDisappear { presenter.onViewDisappear() }
    }

}

extension CoreBuilder {
    func exerciseFrequencyView(router: AnyRouter, delegate: ExerciseFrequencyDelegate) -> some View {
        ExerciseFrequencyView(
            presenter: ExerciseFrequencyPresenter(interactor: interactor, router: CoreRouter(router: router, builder: self)),
            delegate: delegate
        )
    }
}

extension CoreRouter {
    func showExerciseFrequencyView(delegate: ExerciseFrequencyDelegate) {
        router.showScreen(.push) { router in
            builder.exerciseFrequencyView(router: router, delegate: delegate)
        }
    }

}

#Preview {
    let builder = CoreBuilder(interactor: CoreInteractor(container: DevPreview.shared.container()))
    RouterView { router in
        builder.exerciseFrequencyView(
            router: router,
            delegate: .mock
        )
    }
    
}
