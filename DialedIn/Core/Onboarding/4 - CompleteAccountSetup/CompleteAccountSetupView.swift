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
            onDevSettingsPressed: onDevSettingsPressed
        ) {
            Section {
                Text("In order to for us to help you on your fitness journey, we need to know a few things about you. These will help us tailor our recommendations to your needs.")
            } header: {
                Text("The Basics")
            }
        }
        .navigationBarBackButtonHidden()
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
