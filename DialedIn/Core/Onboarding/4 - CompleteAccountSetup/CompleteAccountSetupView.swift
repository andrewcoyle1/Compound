//
//  CompleteAccountSetupView.swift
//  DialedIn
//
//  Created by Andrew Coyle on 04/10/2025.
//

import SwiftUI

struct CompleteAccountSetupView: View {

    @State var presenter: CompleteAccountSetupPresenter

    var body: some View {
        OnboardingStepScaffold(
            title: "Ready to Begin?",
            progress: OnboardingStep.completeAccountSetup.progress,
            primary: .init(title: "Continue", identifier: "Continue") { presenter.handleNavigation() },
            onDevSettingsPressed: nil
        ) {
            Section {
                Text("A few details tailor your recommendations to your fitness journey.")
            } header: {
                Text("The Basics")
            }
        }
        .navigationBarBackButtonHidden()
    }

}

extension CoreBuilder {
    func completeAccountSetupView(router: AnyRouter) -> some View {
        CompleteAccountSetupView(
            presenter: CompleteAccountSetupPresenter(interactor: interactor, router: CoreRouter(router: router, builder: self))
        )
    }
}

extension CoreRouter {
    func showCompleteAccountSetupView() {
        router.showScreen(.push) { router in
            builder.completeAccountSetupView(router: router)
        }
    }
}

#Preview {
    let builder = CoreBuilder(interactor: CoreInteractor(container: DevPreview.shared.container()))
    RouterView { router in
        builder.completeAccountSetupView(router: router)
    }
    
}
