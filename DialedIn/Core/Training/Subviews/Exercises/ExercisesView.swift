//
//  ExercisesView.swift
//  DialedIn
//
//  Created by Andrew Coyle on 23/09/2025.
//

import SwiftUI

struct ExercisesView<ExerciseList: View>: View {

    @State var presenter: ExercisesPresenter

    @ViewBuilder var exerciseListViewBuilder: (ExerciseListBuilderDelegate) -> ExerciseList
    
    var body: some View {
        let delegate = ExerciseListBuilderDelegate(onExerciseSelectionChanged: presenter.onExercisePressed)
        exerciseListViewBuilder(delegate)
            .navigationTitle("Exercises")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarVisibility(.visible)
    }
}

extension CoreBuilder {
    func exercisesView(router: AnyRouter) -> some View {
        ExercisesView(
            presenter: ExercisesPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self)
            ),
            exerciseListViewBuilder: { delegate in
                exerciseListBuilderView(router: router, delegate: delegate)
            }
        )
    }
}

extension CoreRouter {
    func showExercisesView() {
        router.showScreen(.push) { router in
            builder.exercisesView(router: router)
        }
    }
}

#Preview {
    let container = DevPreview.shared.container()
    let interactor = CoreInteractor(container: container)
    let builder = CoreBuilder(interactor: interactor)
    RouterView { router in
        builder.exercisesView(router: router)
    }
    
}
