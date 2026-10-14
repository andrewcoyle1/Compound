//
//  CreateWorkoutView.swift
//  Compound
//
//  Created by Andrew Coyle on 24/09/2025.
//

import SwiftUI

struct CreateWorkoutDelegate {
    /// Set when editing; the wizard opens prefilled and the save updates this template.
    var workoutTemplate: WorkoutTemplateModel?
}

extension CoreBuilder {
    /// The workout wizard opens straight on its name, new or edited: a splash in front of it was
    /// one more tap with nothing to decide.
    func createWorkoutView(router: AnyRouter, delegate: CreateWorkoutDelegate) -> some View {
        nameWorkoutView(
            router: router,
            delegate: NameWorkoutDelegate(workoutTemplate: delegate.workoutTemplate)
        )
    }
}

extension CoreRouter {
    func showCreateWorkoutView(delegate: CreateWorkoutDelegate) {
        router.showScreen(.fullScreenCover) { router in
            builder.createWorkoutView(router: router, delegate: delegate)
        }
    }
}

#Preview {
    let container = DevPreview.shared.container()
    let builder = CoreBuilder(interactor: CoreInteractor(container: container))
    RouterView { router in
        builder.createWorkoutView(router: router, delegate: CreateWorkoutDelegate())
    }
}
