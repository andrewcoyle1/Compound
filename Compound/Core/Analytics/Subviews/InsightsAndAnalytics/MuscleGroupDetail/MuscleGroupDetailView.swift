//
//  MuscleGroupDetailView.swift
//  Compound
//
//  Created by Cursor on 07/02/2026.
//

import SwiftUI

struct MuscleGroupDetailDelegate {
}

struct MuscleGroupDetailView: View {

    @State var presenter: MuscleGroupDetailPresenter
    let delegate: MuscleGroupDetailDelegate

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
    let delegate = MuscleGroupDetailDelegate()

    return RouterView { router in
        builder.muscleGroupDetailView(router: router, delegate: delegate, muscle: .upperBack)
    }
    
}

extension CoreBuilder {

    func muscleGroupDetailView(router: AnyRouter, delegate: MuscleGroupDetailDelegate, muscle: Muscles, themeColor: Color? = nil) -> some View {
        MetricDetailView(
            presenter: MuscleGroupDetailPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self),
                muscle: muscle
            ),
            themeColor: themeColor
        )
    }
}

extension CoreRouter {

    func showMuscleGroupDetailView(muscle: Muscles, delegate: MuscleGroupDetailDelegate, themeColor: Color? = nil) {
        router.showScreen(.push) { router in
            builder.muscleGroupDetailView(router: router, delegate: delegate, muscle: muscle, themeColor: themeColor)
        }
    }
}
