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
        router.showSetTargetView(delegate: SetTargetDelegate(exercise: exercise, scope: .template))
    }

    /// A superset left with one member is dissolved.
    func removeExercise(exercise: WorkoutTemplateExercise) {
        guard exercises.contains(where: { $0.id == exercise.id }) else { return }
        exercises = DefineWorkoutRules.dissolvingLoneGroups(exercises.filter { $0.id != exercise.id })
    }

    /// The order was the order exercises were picked in; moving one meant removing and re-adding
    /// everything after it. A superset moves as one.
    func moveExercises(from source: IndexSet, to destination: Int) {
        exercises = DefineWorkoutRules.moving(exercises, from: source, to: destination)
    }

    func deleteExercises(at offsets: IndexSet) {
        var remaining = exercises
        remaining.remove(atOffsets: offsets)
        exercises = DefineWorkoutRules.dissolvingLoneGroups(remaining)
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

    // MARK: - The row

    /// "3 warm-ups · 2:00 rest · 2 alternatives", only the parts the plan sets.
    func planSummary(for exercise: WorkoutTemplateExercise) -> String? {
        DefineWorkoutRules.planSummary(for: exercise)
    }

    /// "A", "B"… for a member of a superset, by first appearance.
    func supersetLetter(for exercise: WorkoutTemplateExercise) -> String? {
        exercise.supersetGroupId.flatMap { DefineWorkoutRules.supersetLetters(exercises)[$0] }
    }

    func supersetAccessibilityLabel(letter: String) -> String {
        String(localized: "Superset \(letter)")
    }

    // MARK: - Supersets

    /// Choosing exercises to run as one superset, from the list's edit mode.
    private(set) var isSelectingSuperset = false
    private(set) var supersetSelection: Set<String> = []

    var canStartSuperset: Bool { exercises.count >= 2 }
    var canConfirmSuperset: Bool { supersetSelection.count >= 2 }

    func isSelectedForSuperset(_ exercise: WorkoutTemplateExercise) -> Bool {
        supersetSelection.contains(exercise.id)
    }

    func onSupersetPressed() {
        guard canStartSuperset else { return }
        supersetSelection = []
        isSelectingSuperset = true
    }

    func onSupersetRowPressed(_ exercise: WorkoutTemplateExercise) {
        guard isSelectingSuperset else { return }
        if supersetSelection.contains(exercise.id) {
            supersetSelection.remove(exercise.id)
        } else {
            supersetSelection.insert(exercise.id)
        }
        interactor.playHaptic(option: .selection)
    }

    func onSupersetCancelPressed() {
        supersetSelection = []
        isSelectingSuperset = false
    }

    /// The chosen two or more become one superset, side by side where the first of them is.
    func onSupersetConfirmPressed() {
        guard canConfirmSuperset else { return }
        let count = supersetSelection.count
        exercises = DefineWorkoutRules.grouping(supersetSelection, in: exercises, groupId: UUID().uuidString)
        onSupersetCancelPressed()
        interactor.playHaptic(option: .success)
        interactor.trackEvent(event: Event.supersetCreated(count: count))
    }

    func onRemoveFromSupersetPressed(_ exercise: WorkoutTemplateExercise) {
        exercises = DefineWorkoutRules.removingFromSuperset(exercise.id, in: exercises)
        interactor.trackEvent(event: Event.supersetRemoved)
    }
}

extension DefineWorkoutPresenter {
    enum Event: LoggableEvent {
        case supersetCreated(count: Int)
        case supersetRemoved

        var eventName: String {
            switch self {
            case .supersetCreated: return "DefineWorkoutView_Superset_Created"
            case .supersetRemoved: return "DefineWorkoutView_Superset_Removed"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .supersetCreated(let count): return ["exercise_count": count]
            case .supersetRemoved: return nil
            }
        }

        var type: LogType { .analytic }
    }
}
