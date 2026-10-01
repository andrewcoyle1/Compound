//
//  WorkoutView.swift
//  Compound
//
//  Created by Cursor on 07/02/2026.
//

import SwiftUI

struct WorkoutDelegate {
}

struct WorkoutView: View {

    @State var presenter: WorkoutPresenter
    let delegate: WorkoutDelegate

    var body: some View {
        MetricDetailView(presenter: presenter)
    }
}

#Preview {
    let container = DevPreview.shared.container()
    let interactor = CoreInteractor(container: container)
    let builder = CoreBuilder(interactor: interactor)
    let delegate = WorkoutDelegate()

    return RouterView { router in
        builder.workoutView(router: router, delegate: delegate)
    }
    
}

extension CoreBuilder {

    func workoutView(router: AnyRouter, delegate: WorkoutDelegate, themeColor: Color? = nil) -> some View {
        MetricDetailView(
            presenter: WorkoutPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self)
            ),
            themeColor: themeColor
        )
    }
}

extension CoreRouter {

    func showWorkoutView(delegate: WorkoutDelegate, themeColor: Color? = nil) {
        router.showScreen(.push) { router in
            builder.workoutView(router: router, delegate: delegate, themeColor: themeColor)
        }
    }
}
