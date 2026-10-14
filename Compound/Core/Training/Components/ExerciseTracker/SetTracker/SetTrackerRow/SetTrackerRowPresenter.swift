import SwiftUI

@Observable
@MainActor
class SetTrackerRowPresenter {
    
    private let interactor: SetTrackerRowInteractor
    private let router: SetTrackerRowRouter
    
    var restPickerMinutesSelection: Int = 0
    var restPickerSecondsSelection: Int = 0
    var restBeforeSetIdToSec: [String: Int] = [:]
    /// See `SetTrackerRowDelegate.onLogSet`.
    var onLogSet: (@MainActor (String, Int?) -> Void)?
    var onCustomRestChanged: (@MainActor (String, Int?) -> Void)?

    /// The weight and reps keyboards for this row.
    let keyboard = SetKeyboardPresenter()
    /// The set the keyboard was last opened on, so the plate calculator knows what it is for.
    @ObservationIgnored private var keyboardDelegate: SetTrackerRowDelegate?

    init(interactor: SetTrackerRowInteractor, router: SetTrackerRowRouter) {
        self.interactor = interactor
        self.router = router
        keyboard.playSelectionHaptic = { [interactor] in interactor.playHaptic(option: .selection) }
        keyboard.openPlateCalculator = { [weak self] in self?.onPlateCalculatorPressed() }
        keyboard.onComplete = { [weak self] in self?.onKeyboardDone() ?? true }
    }
    
    /// A left set and its right partner are one set, so swiping either away removes both — a
    /// surviving half would number and rest as a set of its own. Its drops and mini-sets go too.
    func deleteSet(setId: String, exercise: Binding<WorkoutExerciseModel>) {
        let removing = Set(ActiveWorkout.idsRemovedByDeleting(setId, in: exercise.wrappedValue.sets))
        guard !removing.isEmpty else { return }
        exercise.wrappedValue.sets.removeAll(where: { removing.contains($0.id) })
    }

    /// Deletes the set, asking first when its drops or mini-sets would go with it: "Delete Set 2?
    /// This also deletes its 2 drop sets."
    func onDeleteSetPressed(setId: String, setName: String, exercise: Binding<WorkoutExerciseModel>) {
        let removed = ActiveWorkout.subSetsRemovedByDeleting(setId, in: exercise.wrappedValue.sets)
        let message: String
        switch (removed.drops, removed.minis) {
        case (0, 0): return deleteSet(setId: setId, exercise: exercise)
        case (let drops, 0): message = String(localized: "This also deletes its \(drops) drop sets.")
        case (0, let minis): message = String(localized: "This also deletes its \(minis) mini-sets.")
        case (let drops, let minis): message = String(localized: "This also deletes its \(drops + minis) drop sets and mini-sets.")
        }
        router.showConfirmationDialog(title: String(localized: "Delete \(setName)?"), subtitle: message) {
            AnyView(VStack(spacing: Spacing.s) {
                Button("Delete", role: .destructive) { self.deleteSet(setId: setId, exercise: exercise) }
                Button("Cancel", role: .cancel) { }
            })
        }
    }

    /// A drop or mini-set under the set, after any it has: a drop 20 % lighter
    /// (`ActiveWorkout.dropWeightKg`), a mini-set at the set's weight, the reps left to fill in.
    func addSubSet(_ subKind: SubSetKind, to setId: String, exercise: Binding<WorkoutExerciseModel>) {
        let current = exercise.wrappedValue
        guard let parent = current.sets.first(where: { $0.id == setId }) else { return }
        let weightKg = subKind == .drop ? dropWeightKg(below: parent, in: current) : parent.weightKg
        let sets = ActiveWorkout.addingSubSet(subKind, to: setId, in: current.sets, id: UUID().uuidString, weightKg: weightKg)
        withReducedMotionAnimation(.standard) {
            exercise.wrappedValue.sets = sets
        }
        interactor.playHaptic(option: .selection)
    }

    /// The set number's menu: makes the set a warm-up, a drop set, a myo set… A drop or myo set
    /// gets its first drop or mini-set (`ActiveWorkout.applying`), and sub-rows the new type has
    /// no use for go, asking first when any of them is logged.
    func onSetTypeSelected(_ choice: SetTypeChoice, setId: String, setName: String, exercise: Binding<WorkoutExerciseModel>) {
        let current = exercise.wrappedValue
        guard let set = current.sets.first(where: { $0.id == setId }), set.typeChoice != choice else { return }
        let updated = ActiveWorkout.applying(
            choice,
            to: setId,
            in: current.sets,
            firstSubSetId: UUID().uuidString,
            dropWeightKg: dropWeightKg(below: set, in: current)
        )
        let kept = Set(updated.map(\.id))
        let loggedLost = current.sets.filter { $0.completedAt != nil && !kept.contains($0.id) }.count
        guard loggedLost > 0 else { return applySetType(choice, sets: updated, exercise: exercise) }
        router.showConfirmationDialog(
            title: String(localized: "Change \(setName) to \(choice.displayName)?"),
            subtitle: String(localized: "This deletes \(loggedLost) logged rows under it.")
        ) {
            AnyView(VStack(spacing: Spacing.s) {
                Button("Change", role: .destructive) { self.applySetType(choice, sets: updated, exercise: exercise) }
                Button("Cancel", role: .cancel) { }
            })
        }
    }

    private func applySetType(_ choice: SetTypeChoice, sets: [WorkoutSetModel], exercise: Binding<WorkoutExerciseModel>) {
        withReducedMotionAnimation(.standard) {
            exercise.wrappedValue.sets = sets
        }
        interactor.playHaptic(option: .selection)
        interactor.trackEvent(event: Event.setTypeChanged(type: choice.eventValue))
    }

    /// A drop's starting weight under `parent`: 20 % off, to a weight the equipment makes.
    private func dropWeightKg(below parent: WorkoutSetModel, in exercise: WorkoutExerciseModel) -> Double? {
        let unit = getUnitPreference(for: exercise).weightUnit
        let step = WeightStepper.steps(for: exercise, profile: interactor.workoutGymProfile, unit: unit)
        return ActiveWorkout.dropWeightKg(from: parent.weightKg, step: step, unit: unit)
    }
    
    /// On the live tracker the set is logged by the tracker, which rests and re-suggests after
    /// it. Elsewhere (a finished workout's editor, the warm-up sheet) the row ticks it itself.
    func onSetComplete(_ exercise: WorkoutExerciseModel, _ set: Binding<WorkoutSetModel>) {
        if set.wrappedValue.completedAt == nil, let onLogSet {
            onLogSet(set.wrappedValue.id, restBeforeSetIdToSec[set.wrappedValue.id])
        } else if set.wrappedValue.completedAt == nil {
            guard validateSetData(trackingMode: exercise.trackingMode, set: set.wrappedValue, isAssisted: isAssisted(exercise)) else {
                interactor.playHaptic(option: .error)
                return
            }
            set.wrappedValue = exercise.stamping(set.wrappedValue)
            set.wrappedValue.completedAt = Date()
            interactor.playHaptic(option: .success)
            let useRestTimers = interactor.workoutSettings.useRestTimers
            let duration = restAfterCompleting(set.wrappedValue, in: exercise)
            interactor.trackEvent(event: Event.setCompleted(
                setId: set.wrappedValue.id,
                exerciseId: exercise.id,
                useRestTimers: useRestTimers,
                restDurationSeconds: duration ?? 0
            ))
        } else {
            set.wrappedValue.completedAt = nil
        }
    }

    /// How long to rest after this set, or `nil` when the settings say not to rest here at all.
    ///
    /// The rules themselves are in `RestDurationRules`, shared with the Live Activity intent
    /// handler so a set logged from the widget rests for exactly as long as one logged here.
    func restAfterCompleting(_ set: WorkoutSetModel, in exercise: WorkoutExerciseModel) -> Int? {
        RestDurationRules.restAfterCompleting(
            set,
            in: exercise,
            settings: interactor.workoutSettings,
            context: restContext(for: exercise),
            customRestSeconds: restBeforeSetIdToSec[set.id]
        )
    }

    /// What the rules need to know about this exercise, read off the interactor.
    private func restContext(for exercise: WorkoutExerciseModel) -> RestDurationRules.ExerciseContext {
        RestDurationRules.ExerciseContext(
            restOverrideSeconds: interactor.exerciseRestOverride(for: exercise.templateId),
            exerciseTypeRawValue: interactor.allExercises.first(where: { $0.id == exercise.templateId })?.type?.rawValue,
            planRestSeconds: exercise.restSeconds
        )
    }

    func onRestPickerRequested(exercise: WorkoutExerciseModel, setId: String) {
        // Open on the rest that would actually run for this set, scaling included. A rest already
        // set by hand is keyed by id alone, so it is honoured whether or not the set is among the
        // ones passed in. Where the settings say no rest runs here, offer the unscaled base
        // instead — the user opening the picker plainly wants a rest, and there is nothing else to
        // show them.
        let existing = restBeforeSetIdToSec[setId]
            ?? exercise.sets.first(where: { $0.id == setId })
                .flatMap { restAfterCompleting($0, in: exercise) }
            ?? RestDurationRules.baseRestDuration(settings: interactor.workoutSettings, context: restContext(for: exercise))
        restPickerMinutesSelection = existing / 60
        restPickerSecondsSelection = existing % 60

        router.showRestModal(
            primaryButtonAction: { [weak self] in
                guard let self else { return }
                let total = (self.restPickerMinutesSelection * 60) + self.restPickerSecondsSelection
                let seconds = total > 0 ? total : nil
                self.updateRestBefore(setId: setId, seconds: seconds)
            },
            // The sheet closes itself; there is nothing to undo, as the pickers write to this
            // presenter's selection and only Save applies it.
            secondaryButtonAction: { },
            minutesSelection: Binding(
                get: { self.restPickerMinutesSelection },
                set: { self.restPickerMinutesSelection = $0 }
            ),
            secondsSelection: Binding(
                get: { self.restPickerSecondsSelection },
                set: { self.restPickerSecondsSelection = $0 }
            )
        )
    }

    func updateRestBefore(setId: String, seconds: Int?) {
        if let seconds {
            restBeforeSetIdToSec[setId] = seconds
        } else {
            restBeforeSetIdToSec.removeValue(forKey: setId)
        }
        onCustomRestChanged?(setId, seconds)
    }

    /// Read from `ExerciseUnitPreferenceManager` every time. Each presenter used to keep its own
    /// copy, and a row's copy outlived a switch to pounds: the header said lb while the keypad
    /// still converted from kg, so a typed 50 lb was stored as 50 kg.
    func getUnitPreference(for exercise: WorkoutExerciseModel) -> (weightUnit: ExerciseWeightUnit, distanceUnit: ExerciseDistanceUnit) {
        let preference = interactor.getPreference(templateId: exercise.templateId)
        return (weightUnit: exercise.weightUnit ?? preference.weightUnit, distanceUnit: preference.distanceUnit)
    }

    func validateSetData(trackingMode: TrackingMode, set: WorkoutSetModel, isAssisted: Bool = false) -> Bool {
        guard let problem = SetValidation.problem(with: set, trackingMode: trackingMode, isAssisted: isAssisted) else { return true }
        router.showSimpleAlert(title: String(localized: "Unable to Log Set"), subtitle: problem)
        return false
    }

    func canComplete(trackingMode: TrackingMode, set: WorkoutSetModel, isAssisted: Bool = false) -> Bool {
        SetValidation.canLog(set, trackingMode: trackingMode, isAssisted: isAssisted)
    }

    /// Whether `exercise`'s weight is assistance, stored negative (`ExerciseModel.isAssisted`).
    func isAssisted(_ exercise: WorkoutExerciseModel) -> Bool {
        interactor.allExercises.first { $0.id == exercise.templateId }?.isAssisted ?? false
    }

    /// What the Done column shows. Each state has its own symbol and spoken value, so none of them
    /// is told apart by colour alone.
    func completionState(trackingMode: TrackingMode, set: WorkoutSetModel, isAssisted: Bool = false) -> SetCompletionState {
        if set.completedAt != nil { return .completed }
        return canComplete(trackingMode: trackingMode, set: set, isAssisted: isAssisted) ? .ready : .notReady
    }
}

enum SetCompletionState: Equatable {
    case completed
    /// Holds what its tracking mode needs; a tap logs it.
    case ready
    /// Missing reps, a time or a distance, so it cannot be logged yet.
    case notReady

    var systemImage: String {
        switch self {
        case .completed: return "checkmark.circle.fill"
        case .ready: return "circle"
        case .notReady: return "circle.dashed"
        }
    }

    var tint: Color {
        switch self {
        case .completed: return .success
        case .ready: return .secondary
        case .notReady: return .secondary.opacity(0.5)
        }
    }

    var accessibilityValue: String {
        switch self {
        case .completed: return ""
        case .ready: return String(localized: "Ready")
        case .notReady: return String(localized: "Not ready, enter the set first")
        }
    }
}

// MARK: - Keyboard

extension SetTrackerRowPresenter {

    /// A weight or reps field took focus: open its keyboard on what this set and exercise allow.
    func onKeyboardFieldBegan(_ field: SetKeyboardField, delegate: SetTrackerRowDelegate) {
        keyboardDelegate = delegate
        keyboard.open(field, set: delegate.set, context: keyboardContext(delegate: delegate))
    }

    /// The keypad's ✓ on the row's last field logs the set as its Done column does. A logged set
    /// only closes; one missing what its tracking mode needs stays open, with an error haptic.
    func onKeyboardDone() -> Bool {
        guard let delegate = keyboardDelegate else { return true }
        let exercise = delegate.exercise.wrappedValue
        switch completionState(trackingMode: exercise.trackingMode, set: delegate.set.wrappedValue, isAssisted: isAssisted(exercise)) {
        case .completed:
            return true
        case .notReady:
            interactor.playHaptic(option: .error)
            return false
        case .ready:
            onSetComplete(exercise, delegate.set)
            return true
        }
    }

    /// The loading bar was tapped: the plate calculator for this exercise's bar or plate-loaded
    /// machine in the workout's gym. Done saves the bar and plates chosen to the gym, and the
    /// keyboard steps on them from then on.
    func onPlateCalculatorPressed() {
        guard let delegate = keyboardDelegate, let gym = interactor.workoutGymProfile else { return }
        let exercise = delegate.exercise.wrappedValue
        let unit = getUnitPreference(for: exercise).weightUnit
        // The bar or machine, plates on or not: with none on, this is where they go back on.
        guard let equipment = exercise.activeVariation?.resistanceEquipment.first(where: {
            WeightStepper.steps(for: [$0], profile: gym, unit: unit).baseWeight != nil
        }) else { return }
        let total = delegate.set.wrappedValue.weightKg.map { (UnitConversion.convertWeight($0, to: unit) * 1000).rounded() / 1000 }
        router.showPlateCalculatorView(delegate: PlateCalculatorDelegate(
            gym: gym,
            equipment: equipment,
            unit: unit,
            total: total,
            machineBase: delegate.set.wrappedValue.machineBaseKg.map { UnitConversion.convertWeight($0, to: unit) } ?? 0
        ) { [weak self] updated in
            self?.onGymLoadingChanged(updated)
        })
    }

    /// Only what the sheet changes, the bar chosen and the plates on, goes onto the gym as it is
    /// now: the sheet's copy was taken when it opened.
    private func onGymLoadingChanged(_ edited: GymProfileModel) {
        let gym = interactor.workoutGymProfile.map { $0.id == edited.id ? $0.takingLoading(from: edited) : edited } ?? edited
        Task {
            do {
                try await interactor.saveWorkoutGymProfile(gym)
            } catch {
                router.showSimpleAlert(title: String(localized: "Unable to Save Gym"), subtitle: error.localizedDescription)
            }
        }
        // From the edited gym, not the interactor's: the save has not run yet when this does.
        if keyboard.activeField != nil, let delegate = keyboardDelegate {
            keyboard.refresh(context: keyboardContext(delegate: delegate, gym: gym))
        }
    }

    /// `gym` overrides the workout's gym, for a change not yet saved back to it.
    func keyboardContext(delegate: SetTrackerRowDelegate, gym: GymProfileModel? = nil) -> SetKeyboardContext {
        let exercise = delegate.exercise.wrappedValue
        let set = delegate.set.wrappedValue
        let units = getUnitPreference(for: exercise)
        let unit = units.weightUnit
        let lastSet = exercise.sets.firstIndex { $0.id == set.id }.flatMap { $0 > 0 ? exercise.sets[$0 - 1] : nil }
        let target = set.isWarmup ? nil : exercise.setTargets.first { $0.setNumber == exercise.workingSetNumber(for: set) }
        // An assisted machine steps below zero, and never above it when the exercise cannot be loaded.
        let library = interactor.allExercises.first { $0.id == exercise.templateId }
        let gym = gym ?? interactor.workoutGymProfile
        let step = WeightStepper.steps(for: exercise, profile: gym, unit: unit)
        return SetKeyboardContext(
            unit: unit,
            step: library?.isAssisted == true ? step.assisted(bodyweightOnly: library?.isBodyweight == true) : step,
            distanceUnit: units.distanceUnit,
            fields: SetKeyboardField.fields(for: set, trackingMode: exercise.trackingMode),
            showsEffort: interactor.workoutSettings.rirTracking,
            targetRIR: target?.effectiveRIRTarget,
            lastSetReps: lastSet?.reps,
            targetMinReps: target?.minReps,
            targetMaxReps: target?.maxReps
        )
    }
}

extension SetTrackerRowPresenter {
    
    enum Event: LoggableEvent {
        /// Every set logged, from a row, the set keyboard or the tracker's log button, which
        /// `source` tells apart.
        case setCompleted(setId: String, exerciseId: String, useRestTimers: Bool, restDurationSeconds: Int, source: String = "row")
        case setTypeChanged(type: String)

        var eventName: String {
            switch self {
            case .setCompleted:             return "SetTrackerRow_SetCompleted"
            case .setTypeChanged:           return "SetTrackerRow_SetTypeChanged"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .setCompleted(let setId, let exerciseId, let useRestTimers, let restDurationSeconds, let source):
                return [
                    "source": source,
                    "set_id": setId,
                    "exercise_id": exerciseId,
                    "use_rest_timers": useRestTimers,
                    "rest_duration_seconds": restDurationSeconds
                ]
            case .setTypeChanged(let type):
                return ["set_type": type]
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
