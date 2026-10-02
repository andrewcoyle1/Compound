//
//  PreferredDietView.swift
//  Compound
//
//  Created by Andrew Coyle on 06/10/2025.
//

import SwiftUI

struct PreferredDietView: View {

    @State var presenter: PreferredDietPresenter

    var body: some View {
        OnboardingStepScaffold(
            title: "What's Your Diet?",
            progress: presenter.isFromSettings ? nil : OnboardingStep.customiseProgram.progress,
            primary: .init(title: "Continue", isEnabled: presenter.selectedDiet != nil, identifier: "Continue") { presenter.navigateToCalorieFloor() },
            onDevSettingsPressed: nil
        ) {
            Section {
                ForEach(PreferredDiet.allCases) { diet in
                    SelectableRow(title: diet.description, subtitle: diet.detailedDescription, isSelected: presenter.selectedDiet == diet) {
                        presenter.onDietSelected(diet)
                    }
                }
            }
        }
    }
}

extension CoreBuilder {
    func preferredDietView(router: AnyRouter, isFromSettings: Bool = false) -> some View {
        PreferredDietView(
            presenter: PreferredDietPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self),
                isFromSettings: isFromSettings
            )
        )
    }
}

extension CoreRouter {
    func showPreferredDietView() {
        router.showScreen(.push) { router in
            builder.preferredDietView(router: router)
        }
    }

    func showPreferredDietView(isFromSettings: Bool) {
        router.showScreen(.push) { router in
            builder.preferredDietView(router: router, isFromSettings: isFromSettings)
        }
    }
}

#Preview {
    let builder = CoreBuilder(interactor: CoreInteractor(container: DevPreview.shared.container()))
    RouterView { router in
        builder.preferredDietView(
            router: router
        )
    }
    
}
