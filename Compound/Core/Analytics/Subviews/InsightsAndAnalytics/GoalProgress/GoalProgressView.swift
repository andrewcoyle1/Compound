//
//  GoalProgressView.swift
//  Compound
//

import SwiftUI

struct GoalProgressDelegate {
}

struct GoalProgressView: View {

    @State var presenter: GoalProgressPresenter
    let delegate: GoalProgressDelegate
    var themeColor: Color?

    var body: some View {
        MetricDetailView(presenter: presenter, themeColor: themeColor)
    }
}

#Preview {
    let container = DevPreview.shared.container()
    let interactor = CoreInteractor(container: container)
    let builder = CoreBuilder(interactor: interactor)
    let delegate = GoalProgressDelegate()

    return RouterView { router in
        builder.goalProgressView(router: router, delegate: delegate)
    }
    
}

extension CoreBuilder {

    func goalProgressView(router: AnyRouter, delegate: GoalProgressDelegate, themeColor: Color? = nil) -> some View {
        GoalProgressView(
            presenter: GoalProgressPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self)
            ),
            delegate: delegate,
            themeColor: themeColor
        )
    }
}

extension CoreRouter {

    func showGoalProgressView(delegate: GoalProgressDelegate, themeColor: Color? = nil) {
        router.showScreen(.push) { router in
            builder.goalProgressView(router: router, delegate: delegate, themeColor: themeColor)
        }
    }
}
