import SwiftUI

@Observable
@MainActor
class DefineWorkoutPresenter {
    
    private let interactor: DefineWorkoutInteractor
    private let router: DefineWorkoutRouter
    private var exercisesBinding: Binding<[WorkoutTemplateExercise]>
    
    /// Local observable mirror of `exercisesBinding` so SwiftUI refreshes when it changes.
    var exercises: [WorkoutTemplateExercise] = [] {
        didSet {
            if exercisesBinding.wrappedValue != exercises {
                exercisesBinding.wrappedValue = exercises
            }
        }
    }
    
    var currentUser: UserModel? {
        interactor.currentUser
    }
        
    var targetMuscleSummaries: [TargetMuscleSummary] {
        MuscleVolume.targetSummaries(exercises: exercises)
    }
    
    init(
        interactor: DefineWorkoutInteractor,
        router: DefineWorkoutRouter,
        exercises: Binding<[WorkoutTemplateExercise]>
    ) {
        self.interactor = interactor
        self.router = router
        self.exercisesBinding = exercises
        self.exercises = exercises.wrappedValue
    }
    
    private var hasAutoOpenedPicker = false

    /// With `autoOpensPicker`, an empty workout opens the exercise picker on its own, once: adding
    /// exercises is the only thing left to do. A mesocycle day passes false, as empty is a rest day.
    /// No screen event: this is built inline by the wrapper and the mesocycle designer, which log
    /// their own.
    func onViewAppear(autoOpensPicker: Bool = false) {
        guard autoOpensPicker, !hasAutoOpenedPicker, exercises.isEmpty else { return }
        hasAutoOpenedPicker = true
        onAddExercisePressed()
    }
    
    func onExercisePressed(exercise: Binding<WorkoutTemplateExercise>) {
        router.showSetTargetView(delegate: SetTargetDelegate(exercise: exercise))
    }
    
    func removeExercise(exercise: WorkoutTemplateExercise) {
        let index = exercises.firstIndex { exerciseItem in
            exercise.id == exerciseItem.id
        }
        guard let index else { return }
        
        exercises.remove(at: index)
    }
    
    /// The order was the order exercises were picked in; moving one meant removing and re-adding
    /// everything after it.
    func moveExercises(from source: IndexSet, to destination: Int) {
        exercises.move(fromOffsets: source, toOffset: destination)
    }

    func deleteExercises(at offsets: IndexSet) {
        exercises.remove(atOffsets: offsets)
    }

    func onAddExercisePressed() {
        router.showExercisesPickerView(
            delegate: ExercisesPickerDelegate(
                addedExercises: Binding(get: { self.exercises }, set: { newValue in
                    self.exercises = newValue
                })
            )
        )
    }
    
}
