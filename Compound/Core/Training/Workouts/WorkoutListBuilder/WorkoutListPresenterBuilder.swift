//
//  WorkoutListPresenterBuilder.swift
//  Compound
//
//  Created by Andrew Coyle on 21/10/2025.
//

import SwiftUI

@Observable
@MainActor
class WorkoutListPresenterBuilder {
    
    private let interactor: WorkoutListInteractorBuilder
    private let router: WorkoutListRouterBuilder

    private(set) var isLoading: Bool = false
    var systemWorkoutTemplates: [WorkoutTemplateModel] {
        interactor.systemWorkoutTemplates
            .sortedByKeyPath(keyPath: \.name, ascending: true)

    }
    
    var userWorkoutTemplates: [WorkoutTemplateModel] {
        interactor.userWorkoutTemplates
            .sortedByKeyPath(keyPath: \.name, ascending: true)
    }
    
    var allWorkoutTemplates: [WorkoutTemplateModel] {
        interactor.allWorkoutTemplates
            .sortedByKeyPath(keyPath: \.name, ascending: true)
    }
    
    var filteredWorkoutTemplates: [WorkoutTemplateModel] {
        allWorkoutTemplates.filter(matchesSearch)
    }

    /// The user's mesocycles that have a workout day, so each day can be started on its own
    /// straight from the mesocycle. Activating a mesocycle used to offer to save its days here as
    /// templates, and those copies then drifted from the days they were copied from.
    var mesocycles: [Mesocycle] {
        interactor.mesocycles
            .filter { !days(of: $0).isEmpty }
            .sortedByKeyPath(keyPath: \.name, ascending: true)
    }

    /// A mesocycle's workout days in its own order, rest days left out and the search applied.
    func days(of mesocycle: Mesocycle) -> [WorkoutTemplateModel] {
        mesocycle.workoutTemplates.filter { !$0.exercises.isEmpty && (searchText.isEmpty || matchesSearch($0)) }
    }

    private func matchesSearch(_ workout: WorkoutTemplateModel) -> Bool {
        let text = searchText.lowercased()
        return workout.name.lowercased().contains(text)
            || workout.description?.lowercased().contains(text) == true
            || workout.exercises.contains { $0.exercise.name.lowercased().contains(text) }
    }
    
    var searchText: String = ""

    var selectedExerciseModel: ExerciseModel?
    var selectedWorkoutTemplate: WorkoutTemplateModel?
    
    var currentUser: UserModel? {
        interactor.currentUser
    }
        
    var workoutsCount: Int {
        allWorkoutTemplates.count + mesocycles.reduce(0) { $0 + days(of: $1).count }
    }
        
    init(
        interactor: WorkoutListInteractorBuilder,
        router: WorkoutListRouterBuilder
    ) {
        self.interactor = interactor
        self.router = router
    }
    
    func onAddWorkoutPressed() {
        interactor.trackEvent(event: Event.onAddWorkoutPressed)
        router.showCreateWorkoutView(delegate: CreateWorkoutDelegate(workoutTemplate: nil))
    }

    /// Picking a workout is what this screen exists for, and it passed straight through to the
    /// delegate untracked — so the one action worth measuring here was never measured.
    /// `mesocycle` is the one the workout is a day of, nil for a library template.
    func onWorkoutPressed(
        workout: WorkoutTemplateModel,
        mesocycle: Mesocycle? = nil,
        onWorkoutPressed: ((WorkoutTemplateModel, Mesocycle?) -> Void)? = nil
    ) {
        interactor.trackEvent(event: Event.workoutSelected(workout: workout, isMesocycleDay: mesocycle != nil))
        onWorkoutPressed?(workout, mesocycle)
    }
}

extension WorkoutListPresenterBuilder {
    enum Event: LoggableEvent {
        case onAddWorkoutPressed
        case workoutSelected(workout: WorkoutTemplateModel, isMesocycleDay: Bool)

        var eventName: String {
            switch self {
            case .onAddWorkoutPressed: return "WorkoutsView_AddWorkoutPressed"
            case .workoutSelected:     return "WorkoutsView_Workout_Selected"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            // Id and name rather than the model's full `eventParameters`: this fires on every tap,
            // and the rest of the record is recoverable from the id.
            case .workoutSelected(let workout, let isMesocycleDay):
                return ["workout_id": workout.id, "workout_name": workout.name, "is_mesocycle_day": isMesocycleDay]
            default:
                return nil
            }
        }

        var type: LogType {
            switch self {
            default:
                return .analytic
            }
        }
    }

}
