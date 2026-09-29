//
//  WeighInConsistencyView.swift
//  DialedIn
//

import SwiftUI

struct WeighInConsistencyDelegate {
}

struct WeighInConsistencyView: View {

    @State var presenter: WeighInConsistencyPresenter
    let delegate: WeighInConsistencyDelegate

    var body: some View {
        MetricDetailView(presenter: presenter)
    }
}

#Preview {
    let container = DevPreview.shared.container()
    let interactor = CoreInteractor(container: container)
    let builder = CoreBuilder(interactor: interactor)
    let delegate = WeighInConsistencyDelegate()

    return RouterView { router in
        builder.weighInConsistencyView(router: router, delegate: delegate)
    }
    
}

extension CoreBuilder {

    func weighInConsistencyView(router: AnyRouter, delegate: WeighInConsistencyDelegate, themeColor: Color? = nil) -> some View {
        MetricDetailView(
            presenter: WeighInConsistencyPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self)
            ),
            themeColor: themeColor
        )
    }
}

extension CoreRouter {

    func showWeighInConsistencyView(delegate: WeighInConsistencyDelegate, themeColor: Color? = nil) {
        router.showScreen(.push) { router in
            builder.weighInConsistencyView(router: router, delegate: delegate, themeColor: themeColor)
        }
    }
}
