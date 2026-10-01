//
//  ExpenditureDetailView.swift
//  Compound
//
//  Created by Cursor on 07/02/2026.
//

import SwiftUI

struct ExpenditureDetailDelegate { }

struct ExpenditureDetailView: View {

    @State var presenter: ExpenditureDetailPresenter
    let delegate: ExpenditureDetailDelegate

    var body: some View {
        MetricDetailView(presenter: presenter)
    }
}

#Preview {
    let container = DevPreview.shared.container()
    let interactor = CoreInteractor(container: container)
    let builder = CoreBuilder(interactor: interactor)
    let delegate = ExpenditureDetailDelegate()

    return RouterView { router in
        builder.expenditureView(router: router, delegate: delegate)
    }
    
}

extension CoreBuilder {

    func expenditureView(router: AnyRouter, delegate: ExpenditureDetailDelegate, themeColor: Color? = nil) -> some View {
        MetricDetailView(
            presenter: ExpenditureDetailPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self)
            ),
            themeColor: themeColor
        )
    }
}

extension CoreRouter {

    func showExpenditureDetailView(delegate: ExpenditureDetailDelegate, themeColor: Color? = nil) {
        router.showScreen(.push) { router in
            builder.expenditureView(router: router, delegate: delegate, themeColor: themeColor)
        }
    }
}
