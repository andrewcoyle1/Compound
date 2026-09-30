//
//  CalorieDistributionView.swift
//  DialedIn
//
//  Created by Andrew Coyle on 06/10/2025.
//

import SwiftUI

struct CalorieDistributionDelegate {
    let preferredDiet: PreferredDiet
    let calorieFloor: CalorieFloor
    var isFromSettings: Bool

    init(delegate: CalorieFloorDelegate, calorieFloor: CalorieFloor) {
        self.preferredDiet = delegate.preferredDiet
        self.calorieFloor = calorieFloor
        self.isFromSettings = delegate.isFromSettings
    }
    
    static var mock: Self {
        Self(delegate: .mock, calorieFloor: .standard)
    }
}

struct CalorieDistributionView: View {

    @State var presenter: CalorieDistributionPresenter

    var delegate: CalorieDistributionDelegate

    var body: some View {
        OnboardingStepScaffold(
            title: "Even or Varied?",
            progress: delegate.isFromSettings ? nil : OnboardingStep.customiseProgram.progress,
            primary: .init(title: "Continue", isEnabled: presenter.selectedCalorieDistribution != nil, identifier: "Continue") { presenter.navigateToProteinIntake(delegate: delegate) },
            onDevSettingsPressed: nil
        ) {
            Section {
                ForEach(CalorieDistribution.allCases) { distribution in
                    SelectableRow(title: distribution.description, subtitle: distribution.detailedDescription, isSelected: presenter.selectedCalorieDistribution == distribution) {
                        presenter.onDistributionSelected(distribution)
                    }
                }
            }
        }
    }
}

extension CoreBuilder {
    func calorieDistributionView(router: AnyRouter, delegate: CalorieDistributionDelegate) -> some View {
        CalorieDistributionView(
            presenter: CalorieDistributionPresenter(interactor: interactor, router: CoreRouter(router: router, builder: self)),
            delegate: delegate
        )
    }
}

extension CoreRouter {
    func showCalorieDistributionView(delegate: CalorieDistributionDelegate) {
        router.showScreen(.push) { router in
            builder.calorieDistributionView(router: router, delegate: delegate)
        }
    }
}

#Preview {
    let builder = CoreBuilder(interactor: CoreInteractor(container: DevPreview.shared.container()))
    RouterView { router in
        builder.calorieDistributionView(
            router: router,
            delegate: .mock
        )
    }
    
}
