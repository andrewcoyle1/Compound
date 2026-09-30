//
//  ActivityView.swift
//  DialedIn
//
//  Created by Andrew Coyle on 04/10/2025.
//

import SwiftUI

struct ActivityDelegate {
    let gender: Gender
    let dateOfBirth: Date
    let heightInCentimetres: Double
    let lengthUnitPreference: LengthUnitPreference
    let weightInKilograms: Double
    let weightUnitPreference: WeightUnitPreference
    let exerciseFrequency: ExerciseFrequency
    
    init(delegate: ExerciseFrequencyDelegate, exerciseFrequency: ExerciseFrequency) {
        self.gender = delegate.gender
        self.dateOfBirth = delegate.dateOfBirth
        self.heightInCentimetres = delegate.heightInCentimetres
        self.lengthUnitPreference = delegate.lengthUnitPreference
        self.weightInKilograms = delegate.weightInKilograms
        self.weightUnitPreference = delegate.weightUnitPreference
        self.exerciseFrequency = exerciseFrequency
    }
    
    static var mock: Self {
        Self(delegate: .mock, exerciseFrequency: .daily)
    }
}

struct ActivityView: View {

    @State var presenter: ActivityPresenter

    var delegate: ActivityDelegate

    var body: some View {
        OnboardingStepScaffold(
            title: "How Active Are You?",
            subtitle: "Your activity outside exercise feeds the calorie estimate.",
            progress: OnboardingStep.completeAccountSetup.progress,
            primary: .init(title: "Continue", isEnabled: presenter.canSubmit, identifier: "Continue") { presenter.onContinuePressed(delegate: delegate) },
            onDevSettingsPressed: nil
        ) {
            Section {
                ForEach(ActivityLevel.allCases, id: \.self) { level in
                    SelectableRow(title: level.description, subtitle: level.detailDescription, isSelected: presenter.selectedActivityLevel == level) {
                        presenter.onActivityLevelSelected(level)
                    }
                }
            }
        }
    }

}

extension CoreBuilder {
    func activityView(router: AnyRouter, delegate: ActivityDelegate) -> some View {
        ActivityView(
            presenter: ActivityPresenter(interactor: interactor, router: CoreRouter(router: router, builder: self)),
            delegate: delegate
        )
    }
}

extension CoreRouter {
    func showActivityView(delegate: ActivityDelegate) {
        router.showScreen(.push) { router in
            builder.activityView(router: router, delegate: delegate)
        }
    }

}

#Preview {
    let builder = CoreBuilder(interactor: CoreInteractor(container: DevPreview.shared.container()))
    RouterView { router in
        builder.activityView(
            router: router,
            delegate: .mock
        )
    }
    
}
