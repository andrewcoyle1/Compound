//
//  NameWorkoutPresenter.swift
//  DialedIn
//
//  Created by Andrew Coyle on 22/10/2025.
//

import SwiftUI

@Observable
@MainActor
class NameWorkoutPresenter {
    
    private let interactor: NameWorkoutInteractor
    private let router: NameWorkoutRouter
    
    var workoutName: String

    /// The exercises chosen further on. Kept here, on the screen the user backs out to, so changing
    /// the name or gym does not throw them away.
    var draftExercises: [WorkoutTemplateExercise]

    private var draftBinding: Binding<[WorkoutTemplateExercise]> {
        Binding(get: { self.draftExercises }, set: { self.draftExercises = $0 })
    }
    var canSave: Bool {
        !workoutName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    init(
        interactor: NameWorkoutInteractor,
        router: NameWorkoutRouter,
        workoutName: String = "",
        draftExercises: [WorkoutTemplateExercise] = []
    ) {
        self.interactor = interactor
        self.router = router
        self.workoutName = workoutName
        self.draftExercises = draftExercises
    }
        
    /// A template being edited already has a gym, so that step is skipped when the gym still exists.
    func onContinuePressed(delegate: NameWorkoutDelegate) {
        let name = workoutName.trimmingCharacters(in: .whitespacesAndNewlines)
        if let template = delegate.workoutTemplate,
           let gym = interactor.gymProfiles.first(where: { $0.id == template.gymProfileId }) {
            router.showDefineWorkoutWrapperView(
                delegate: DefineWorkoutWrapperDelegate(
                    name: name,
                    gymProfile: gym,
                    workoutTemplate: template,
                    draftExercises: draftBinding
                )
            )
        } else {
            router.showChooseGymProfileView(
                delegate: ChooseGymProfileDelegate(name: name, workoutTemplate: delegate.workoutTemplate, draftExercises: draftBinding)
            )
        }
    }

    func onClosePressed() {
        router.dismissEnvironment()
    }

}
