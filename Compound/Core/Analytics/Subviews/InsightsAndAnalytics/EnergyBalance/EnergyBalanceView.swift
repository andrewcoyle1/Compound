//
//  EnergyBalanceView.swift
//  Compound
//
//  Created by Cursor on 07/02/2026.
//

import SwiftUI

struct EnergyBalanceDelegate {
}

struct EnergyBalanceView: View {

    @State var presenter: EnergyBalancePresenter
    let delegate: EnergyBalanceDelegate

    var body: some View {
        MetricDetailView(presenter: presenter)
    }
}

#Preview {
    let container = DevPreview.shared.container()
    let interactor = CoreInteractor(container: container)
    let builder = CoreBuilder(interactor: interactor)
    let delegate = EnergyBalanceDelegate()

    return RouterView { router in
        builder.energyBalanceView(router: router, delegate: delegate)
    }
    
}

extension CoreBuilder {

    func energyBalanceView(router: AnyRouter, delegate: EnergyBalanceDelegate, themeColor: Color? = nil) -> some View {
        MetricDetailView(
            presenter: EnergyBalancePresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self)
            ),
            themeColor: themeColor
        )
    }
}

extension CoreRouter {

    func showEnergyBalanceView(delegate: EnergyBalanceDelegate, themeColor: Color? = nil) {
        router.showScreen(.push) { router in
            builder.energyBalanceView(router: router, delegate: delegate, themeColor: themeColor)
        }
    }
}
