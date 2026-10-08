import SwiftUI

@MainActor
protocol SetTrackerRowInteractor: GlobalInteractor {
    /// Load unit preferences for an exercise template.
    func getPreference(templateId: String) -> ExerciseUnitPreference
    var workoutSettings: WorkoutSettings { get }
    var allExercises: [ExerciseModel] { get }
    /// The rest this one exercise was given on its own settings screen, if any.
    func exerciseRestOverride(for exerciseId: String) -> Int?
    var favouriteGymProfile: GymProfileModel? { get }
    /// The gym whose equipment sets the weight keyboard's steps and plates: the workout's own,
    /// else the favourite.
    var workoutGymProfile: GymProfileModel? { get }
}

extension SetTrackerRowInteractor {
    /// For a conformer with no workout gym of its own to report, the favourite.
    var workoutGymProfile: GymProfileModel? { favouriteGymProfile }
}

extension CoreInteractor: SetTrackerRowInteractor { }
