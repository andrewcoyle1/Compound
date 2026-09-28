//
//  CoreBuilder.swift
//  DialedIn
//
//  Created by Andrew Coyle on 10/11/2025.
//

import SwiftUI

@MainActor
struct CoreBuilder: Builder {
    
    let interactor: CoreInteractor
    
    func build() -> AnyView {
        appView().any()
    }
}

extension CoreBuilder {

    func ratingsModal(onYesPressed: @escaping () -> Void, onNoPressed: @escaping () -> Void) -> some View {
        CustomModalView(
            title: String(localized: "Are you enjoying Compound?"),
            subtitle: String(localized: "We'd love to hear your feedback!"),
            primaryButtonTitle: "Yes",
            primaryButtonAction: {
                onYesPressed()
            },
            secondaryButtonTitle: "No",
            secondaryButtonAction: {
                onNoPressed()
            }
        )
    }
}
