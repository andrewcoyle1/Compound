//
//  WeightTrendView.swift
//  Compound
//
//  Created by Cursor on 07/02/2026.
//

import SwiftUI

struct WeightTrendDelegate {
}

struct WeightTrendView: View {

    @State var presenter: WeightTrendPresenter
    let delegate: WeightTrendDelegate

    var body: some View {
        MetricDetailView(presenter: presenter)
            .toolbar {
                AskCoachToolbarItem { presenter.onAskCoachPressed() }
            }
    }
}

#Preview {
    let container = DevPreview.shared.container()
    let interactor = CoreInteractor(container: container)
    let builder = CoreBuilder(interactor: interactor)
    let delegate = WeightTrendDelegate()

    return RouterView { router in
        builder.weightTrendView(router: router, delegate: delegate)
    }
    
}

extension CoreBuilder {

    func weightTrendView(router: AnyRouter, delegate: WeightTrendDelegate, themeColor: Color? = nil) -> some View {
        MetricDetailView(
            presenter: WeightTrendPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self)
            ),
            themeColor: themeColor
        )
    }
}

extension CoreRouter {

    func showWeightTrendView(delegate: WeightTrendDelegate, themeColor: Color? = nil) {
        router.showScreen(.push) { router in
            builder.weightTrendView(router: router, delegate: delegate, themeColor: themeColor)
        }
    }
}
