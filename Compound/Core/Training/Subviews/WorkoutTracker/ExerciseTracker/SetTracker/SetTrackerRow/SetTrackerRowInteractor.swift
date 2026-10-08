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
    /// Saves a change to the workout's gym made from inside the workout (the plate calculator's
    /// bar and plates), and makes it the gym the keyboard reads at once.
    func saveWorkoutGymProfile(_ profile: GymProfileModel) async throws
}

extension SetTrackerRowInteractor {
    /// For a conformer with no workout gym of its own to report, the favourite.
    var workoutGymProfile: GymProfileModel? { favouriteGymProfile }
    /// For a conformer with no gym to save to (test doubles): nothing.
    func saveWorkoutGymProfile(_ profile: GymProfileModel) async throws { }
}

extension CoreInteractor: SetTrackerRowInteractor { }
