//
//  WorkoutsView.swift
//  Compound
//
//  Created by Andrew Coyle on 23/09/2025.
//

import SwiftUI

struct WorkoutsDelegate {
    var onWorkoutSelectionChanged: ((WorkoutTemplateModel) -> Void)?
}

struct WorkoutsView<WorkoutList: View>: View {

    @State var presenter: WorkoutsPresenter
    let delegate: WorkoutsDelegate
    @ViewBuilder var workoutListViewBuilder: (WorkoutListDelegateBuilder) -> WorkoutList
    
    var body: some View {
        let delegate = WorkoutListDelegateBuilder(
            onWorkoutSelectionChanged: presenter.onWorkoutPressed,
        )
        workoutListViewBuilder(delegate)
    }
}

extension CoreBuilder {
    func workoutsView(router: AnyRouter, delegate: WorkoutsDelegate) -> some View {
        WorkoutsView(
            presenter: WorkoutsPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self)
            ),
            delegate: delegate,
            workoutListViewBuilder: { delegate in
                self.workoutListViewBuilder(router: router, delegate: delegate)
            }
        )
    }
}

extension CoreRouter {
    func showWorkoutsView(delegate: WorkoutsDelegate) {
        router.showScreen(.push) { router in
            builder.workoutsView(router: router, delegate: delegate)
        }
    }
}

#Preview {
    let container = DevPreview.shared.container()
    let interactor = CoreInteractor(container: container)
    let builder = CoreBuilder(interactor: interactor)
    let delegate = WorkoutsDelegate()
    RouterView { router in
        builder.workoutsView(router: router, delegate: delegate)
    }
    
}
