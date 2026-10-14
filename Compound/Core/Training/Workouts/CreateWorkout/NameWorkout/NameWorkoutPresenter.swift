//
//  NameWorkoutPresenter.swift
//  Compound
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
        
    /// Return on the keyboard continues, once there is a name to continue with.
    func onNameSubmitted(delegate: NameWorkoutDelegate) {
        guard canSave else { return }
        onContinuePressed(delegate: delegate)
    }

    /// The gym step is skipped when there is nothing to choose: a template being edited whose gym
    /// still exists, or a user with only one gym.
    func onContinuePressed(delegate: NameWorkoutDelegate) {
        let name = workoutName.trimmingCharacters(in: .whitespacesAndNewlines)
        if let gym = gymWithoutAsking(for: delegate.workoutTemplate) {
            router.showDefineWorkoutWrapperView(
                delegate: DefineWorkoutWrapperDelegate(
                    name: name,
                    gymProfile: gym,
                    workoutTemplate: delegate.workoutTemplate,
                    draftExercises: draftBinding
                )
            )
        } else {
            router.showChooseGymProfileView(
                delegate: ChooseGymProfileDelegate(name: name, workoutTemplate: delegate.workoutTemplate, draftExercises: draftBinding)
            )
        }
    }

    private func gymWithoutAsking(for template: WorkoutTemplateModel?) -> GymProfileModel? {
        if let template, let gym = interactor.gymProfiles.first(where: { $0.id == template.gymProfileId }) {
            return gym
        }
        return interactor.gymProfiles.count == 1 ? interactor.gymProfiles.first : nil
    }

    func onClosePressed() {
        router.dismissEnvironment()
    }

    func onViewAppear() {
        interactor.trackScreenEvent(event: Event.onAppear)
    }

    func onViewDisappear() {
        interactor.trackEvent(event: Event.onDisappear)
    }

    enum Event: LoggableEvent {
        case onAppear
        case onDisappear

        var eventName: String {
            switch self {
            case .onAppear:     return "NameWorkoutView_Appear"
            case .onDisappear:  return "NameWorkoutView_Disappear"
            }
        }

        var parameters: [String: Any]? { nil }

        var type: LogType { .analytic }
    }
}
