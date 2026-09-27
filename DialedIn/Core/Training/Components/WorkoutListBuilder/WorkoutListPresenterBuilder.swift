//
//  WorkoutListPresenterBuilder.swift
//  DialedIn
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
        self.allWorkoutTemplates
            .filter {
                $0.name.lowercased().contains(searchText.lowercased()) ||
                $0.description?.lowercased().contains(searchText.lowercased()) == true ||
                $0.exercises.contains(where: { $0.exercise.name.lowercased().contains(searchText.lowercased()) })
            }
            .sortedByKeyPath(keyPath: \.name, ascending: true)
    }
    
    var searchText: String = ""

    var selectedExerciseModel: ExerciseModel?
    var selectedWorkoutTemplate: WorkoutTemplateModel?
    
    var currentUser: UserModel? {
        interactor.currentUser
    }
        
    var workoutsCount: Int {
        allWorkoutTemplates.count
    }
        
    init(
        interactor: WorkoutListInteractorBuilder,
        router: WorkoutListRouterBuilder
    ) {
        self.interactor = interactor
        self.router = router
    }
    
    func onViewAppear() {
        interactor.trackScreenEvent(event: Event.onAppear)
    }
    
    func onViewDisappear() {
        interactor.trackEvent(event: Event.onDisappear)
    }
    
    func onAddWorkoutPressed() {
        interactor.trackEvent(event: Event.onAddWorkoutPressed)
        router.showCreateWorkoutView(delegate: CreateWorkoutDelegate(workoutTemplate: nil))
    }

    /// Picking a workout is what this screen exists for, and it passed straight through to the
    /// delegate untracked — so the one action worth measuring here was never measured.
    func onWorkoutPressed(
        workout: WorkoutTemplateModel,
        onWorkoutPressed: ((WorkoutTemplateModel) -> Void)? = nil
    ) {
        interactor.trackEvent(event: Event.workoutSelected(workout: workout))
        onWorkoutPressed?(workout)
    }

    #if DEV || MOCK
    func onDevSettingsPressed() {
        router.showDevSettingsView()
    }
    #endif
}

extension WorkoutListPresenterBuilder {
    enum Event: LoggableEvent {
        case onAppear
        case onDisappear
        case onAddWorkoutPressed
        case workoutSelected(workout: WorkoutTemplateModel)

        var eventName: String {
            switch self {
            case .onAppear:            return "WorkoutsView_Appear"
            case .onDisappear:         return "WorkoutsView_Disappear"
            case .onAddWorkoutPressed: return "WorkoutsView_AddWorkoutPressed"
            case .workoutSelected:     return "WorkoutsView_Workout_Selected"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            // Id and name rather than the model's full `eventParameters`: this fires on every tap,
            // and the rest of the record is recoverable from the id.
            case .workoutSelected(workout: let workout):
                return ["workout_id": workout.id, "workout_name": workout.name]
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
