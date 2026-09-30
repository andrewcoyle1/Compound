//
//  GenderView.swift
//  DialedIn
//
//  Created by Andrew Coyle on 04/10/2025.
//

import SwiftUI

struct GenderView: View {

    @State var presenter: GenderPresenter

    var body: some View {
        OnboardingStepScaffold(
            title: "Sex for Calorie Estimate",
            subtitle: "Used only to estimate the calories you burn. You can change it later in Profile.",
            progress: OnboardingStep.completeAccountSetup.progress,
            primary: .init(title: "Continue", isEnabled: presenter.canSubmit, identifier: "Continue") { presenter.onContinuePressed() },
            onDevSettingsPressed: nil
        ) {
            AppleHealthFillSection(state: presenter.healthFill, action: presenter.onFillFromAppleHealthPressed)
            Section {
                ForEach(presenter.options, id: \.self) { gender in
                    SelectableRow(title: gender.description, subtitle: presenter.detail(for: gender), isSelected: presenter.selectedGender == gender) {
                        presenter.onGenderSelected(gender)
                    }
                }
            }
        }
        .onAppear {
            presenter.onViewAppear()
        }
        .onDisappear {
            presenter.onViewDisappear()
        }
    }
}

extension CoreBuilder {
    func genderView(router: AnyRouter) -> some View {
        GenderView(
            presenter: GenderPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self)
            )
        )
    }
}

extension CoreRouter {
    func showGenderView() {
        router.showScreen(.push) { router in
            builder.genderView(router: router)
        }
    }
}

#Preview {
    let builder = CoreBuilder(interactor: CoreInteractor(container: DevPreview.shared.container()))
    RouterView { router in
        builder.genderView(router: router)
    }
    
}
