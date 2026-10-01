//
//  SetTrackerInteractor.swift
//  Compound
//
//  Created by Andrew Coyle on 02/03/2026.
//

@MainActor
protocol SetTrackerInteractor: GlobalInteractor {
    var userId: String? { get }
    var currentUser: UserModel? { get }

    var systemExercises: [ExerciseModel] { get }
    var userExercises: [ExerciseModel] { get }
    
    /// Load unit preferences for an exercise template.
    func getPreference(templateId: String) -> ExerciseUnitPreference

    /// Set the weight unit preference for a specific exercise template
    func setWeightUnit(_ unit: ExerciseWeightUnit, for templateId: String)

    /// Set the distance unit preference for a specific exercise template
    func setDistanceUnit(_ unit: ExerciseDistanceUnit, for templateId: String)

    var favouriteGymProfile: GymProfileModel? { get }
    var workoutGymProfile: GymProfileModel? { get }
    var allExercises: [ExerciseModel] { get }

    var workoutSettings: WorkoutSettings { get }

}

extension CoreInteractor: SetTrackerInteractor { }
