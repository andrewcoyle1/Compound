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
            title: "What's Your Gender?",
            subtitle: "Select your gender",
            progress: OnboardingStep.completeAccountSetup.progress,
            primary: .init(title: "Continue", isEnabled: presenter.canSubmit, identifier: "Continue") { presenter.onContinuePressed() },
            onDevSettingsPressed: onDevSettingsPressed
        ) {
            Section {
                ForEach([Gender.male, .female], id: \.self) { gender in
                    SelectableRow(title: gender.description, isSelected: presenter.selectedGender == gender) {
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

    private var onDevSettingsPressed: (() -> Void)? {
        #if DEV || MOCK
        presenter.onDevSettingsPressed
        #else
        nil
        #endif
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
