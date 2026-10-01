//
//  FoodLoggingConsistencyView.swift
//  Compound
//

import SwiftUI

struct FoodLoggingConsistencyDelegate {}

struct FoodLoggingConsistencyView: View {
    @State var presenter: FoodLoggingConsistencyPresenter
    let delegate: FoodLoggingConsistencyDelegate

    var body: some View {
        MetricDetailView(presenter: presenter)
    }
}

#Preview {
    let container = DevPreview.shared.container()
    let interactor = CoreInteractor(container: container)
    let builder = CoreBuilder(interactor: interactor)
    let delegate = FoodLoggingConsistencyDelegate()

     RouterView { router in
        builder.foodLoggingConsistencyView(router: router, delegate: delegate)
    }
    
}

extension CoreBuilder {
    func foodLoggingConsistencyView(router: AnyRouter, delegate: FoodLoggingConsistencyDelegate, themeColor: Color? = nil) -> some View {
        MetricDetailView(
            presenter: FoodLoggingConsistencyPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self)
            ),
            themeColor: themeColor
        )
    }
}

extension CoreRouter {
    func showFoodLoggingConsistencyView(delegate: FoodLoggingConsistencyDelegate, themeColor: Color? = nil) {
        router.showScreen(.push) { router in
            builder.foodLoggingConsistencyView(router: router, delegate: delegate, themeColor: themeColor)
        }
    }
}
