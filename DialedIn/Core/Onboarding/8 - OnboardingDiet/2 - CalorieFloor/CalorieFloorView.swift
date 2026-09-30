//
//  CalorieFloorView.swift
//  DialedIn
//
//  Created by Andrew Coyle on 06/10/2025.
//

import SwiftUI

struct CalorieFloorDelegate {
    let preferredDiet: PreferredDiet
    var isFromSettings: Bool = false

    static var mock: Self {
        Self(preferredDiet: .balanced)
    }
}

struct CalorieFloorView: View {

    @State var presenter: CalorieFloorPresenter

    var delegate: CalorieFloorDelegate

    var body: some View {
        OnboardingStepScaffold(
            title: "What's Your Floor?",
            progress: delegate.isFromSettings ? nil : OnboardingStep.customiseProgram.progress,
            primary: .init(title: "Continue", isEnabled: presenter.selectedFloor != nil, identifier: "Continue") { presenter.onContinuePressed(delegate: delegate) },
            onDevSettingsPressed: nil
        ) {
            Section {
                ForEach(CalorieFloor.allCases) { floor in
                    SelectableRow(title: floor.description, subtitle: floor.detailedDescription, isSelected: presenter.selectedFloor == floor) {
                        presenter.onFloorSelected(floor)
                    }
                }
            }
        }
    }
}

extension CoreBuilder {
    func calorieFloorView(router: AnyRouter, delegate: CalorieFloorDelegate) -> some View {
        CalorieFloorView(
            presenter: CalorieFloorPresenter(interactor: interactor, router: CoreRouter(router: router, builder: self)),
            delegate: delegate
        )
    }
}

extension CoreRouter {
    func showCalorieFloorView(delegate: CalorieFloorDelegate) {
        router.showScreen(.push) { router in
            builder.calorieFloorView(router: router, delegate: delegate)
        }
    }

}

#Preview {
    let builder = CoreBuilder(interactor: CoreInteractor(container: DevPreview.shared.container()))
    RouterView { router in
        builder.calorieFloorView(
            router: router,
            delegate: .mock
        )
    }
    
}
