//
//  DateOfBirthView.swift
//  DialedIn
//
//  Created by Andrew Coyle on 04/10/2025.
//

import SwiftUI

struct DateOfBirthDelegate {
    let gender: Gender
    
    static var mock: Self {
        Self(gender: .male)
    }
}

struct DateOfBirthView: View {

    @State var presenter: DateOfBirthPresenter

    var delegate: DateOfBirthDelegate

    var body: some View {
        OnboardingStepScaffold(
            title: "When Were You Born?",
            progress: OnboardingStep.completeAccountSetup.progress,
            primary: .init(title: "Continue", identifier: "Continue") { presenter.onContinuePressed(delegate: delegate) },
            onDevSettingsPressed: onDevSettingsPressed
        ) {
            Section {
                DatePicker("Date of birth", selection: $presenter.dateOfBirth, in: presenter.dateRange, displayedComponents: .date)
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
    func dateOfBirthView(router: AnyRouter, delegate: DateOfBirthDelegate) -> some View {
        DateOfBirthView(
            presenter: DateOfBirthPresenter(interactor: interactor, router: CoreRouter(router: router, builder: self)),
            delegate: delegate
        )
    }
}

extension CoreRouter {
    func showDateOfBirthView(delegate: DateOfBirthDelegate) {
        router.showScreen(.push) { router in
            builder.dateOfBirthView(router: router, delegate: delegate)
        }
    }

}

#Preview {
    let builder = CoreBuilder(interactor: CoreInteractor(container: DevPreview.shared.container()))
    RouterView { router in
        builder.dateOfBirthView(
            router: router,
            delegate: .mock
        )
    }
}
