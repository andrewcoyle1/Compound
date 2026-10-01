//
//  StepsView.swift
//  Compound
//
//  Created by Cursor on 07/02/2026.
//

import SwiftUI

struct StepsDelegate {
}

struct StepsView: View {

    @State var presenter: StepsPresenter
    let delegate: StepsDelegate

    var body: some View {
        MetricDetailView(presenter: presenter)
    }
}

#Preview {
    let container = DevPreview.shared.container()
    let interactor = CoreInteractor(container: container)
    let builder = CoreBuilder(interactor: interactor)
    let delegate = StepsDelegate()

    return RouterView { router in
        builder.stepsView(router: router, delegate: delegate)
    }
    
}

extension CoreBuilder {

    func stepsView(router: AnyRouter, delegate: StepsDelegate, themeColor: Color? = nil) -> some View {
        MetricDetailView(
            presenter: StepsPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self)
            ),
            themeColor: themeColor
        )
    }
}

extension CoreRouter {

    func showStepsView(delegate: StepsDelegate, themeColor: Color? = nil) {
        router.showScreen(.push) { router in
            builder.stepsView(router: router, delegate: delegate, themeColor: themeColor)
        }
    }
}
