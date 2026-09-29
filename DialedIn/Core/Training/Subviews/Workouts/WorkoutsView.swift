//
//  WorkoutsView.swift
//  DialedIn
//
//  Created by Andrew Coyle on 23/09/2025.
//

import SwiftUI

struct WorkoutsDelegate {
    var onWorkoutSelectionChanged: ((WorkoutTemplateModel) -> Void)?
    /// Pushed from the Training tab, where the system Back button closes it. Analytics still
    /// presents it as a sheet, which needs its own Close.
    var isPushed = false
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
            .toolbar {
                if !self.delegate.isPushed {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(role: .close) {
                            presenter.onDismissPressed()
                        }
                    }
                }
            }
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
        router.showScreen(delegate.isPushed ? .push : .sheet) { router in
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
