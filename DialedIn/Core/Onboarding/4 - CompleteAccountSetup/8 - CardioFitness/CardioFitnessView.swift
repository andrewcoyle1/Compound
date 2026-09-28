//
//  CardioFitnessView.swift
//  DialedIn
//
//  Created by Andrew Coyle on 04/10/2025.
//

import SwiftUI

struct CardioFitnessDelegate {
    let gender: Gender
    let dateOfBirth: Date
    let heightInCentimetres: Double
    let lengthUnitPreference: LengthUnitPreference
    let weightInKilograms: Double
    let weightUnitPreference: WeightUnitPreference
    let exerciseFrequency: ExerciseFrequency
    let activityLevel: ActivityLevel
    
    init(delegate: ActivityDelegate, activityLevel: ActivityLevel) {
        self.gender = delegate.gender
        self.dateOfBirth = delegate.dateOfBirth
        self.heightInCentimetres = delegate.heightInCentimetres
        self.lengthUnitPreference = delegate.lengthUnitPreference
        self.weightInKilograms = delegate.weightInKilograms
        self.weightUnitPreference = delegate.weightUnitPreference
        self.exerciseFrequency = delegate.exerciseFrequency
        self.activityLevel = activityLevel
    }
    
    static var mock: Self {
        Self(delegate: .mock, activityLevel: .active)
    }

}

struct CardioFitnessView: View {

    @State var presenter: CardioFitnessPresenter

    var delegate: CardioFitnessDelegate

    var body: some View {
        OnboardingStepScaffold(
            title: "How Fit Are You?",
            subtitle: "How would you rate your cardiovascular fitness?",
            progress: OnboardingStep.completeAccountSetup.progress,
            primary: .init(title: "Continue", isEnabled: presenter.canSubmit, identifier: "Continue") { presenter.onContinuePressed(delegate: delegate) },
            onDevSettingsPressed: onDevSettingsPressed
        ) {
            Section {
                ForEach(CardioFitnessLevel.allCases, id: \.self) { level in
                    SelectableRow(title: level.description, subtitle: level.detailDescription, isSelected: presenter.selectedCardioFitness == level) {
                        presenter.onCardioFitnessSelected(level)
                    }
                }
            } footer: {
                Text("Consider your ability to maintain sustained cardio activities like running, cycling, or swimming.")
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
    func cardioFitnessView(router: AnyRouter, delegate: CardioFitnessDelegate) -> some View {
        CardioFitnessView(
            presenter: CardioFitnessPresenter(interactor: interactor, router: CoreRouter(router: router, builder: self)),
            delegate: delegate
        )
    }
}

extension CoreRouter {
    func showCardioFitnessView(delegate: CardioFitnessDelegate) {
        router.showScreen(.push) { router in
            builder.cardioFitnessView(router: router, delegate: delegate)
        }
    }

}

#Preview {
    let builder = CoreBuilder(interactor: CoreInteractor(container: DevPreview.shared.container()))
    RouterView { router in
        builder.cardioFitnessView(
            router: router,
            delegate: .mock
        )
    }
    
}
