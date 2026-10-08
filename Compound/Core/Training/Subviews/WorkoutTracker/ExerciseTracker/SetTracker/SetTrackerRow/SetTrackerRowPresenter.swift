import SwiftUI

@Observable
@MainActor
class SetTrackerRowPresenter {
    
    private let interactor: SetTrackerRowInteractor
    private let router: SetTrackerRowRouter
    
    var restPickerTargetSetId: String?
    var restPickerMinutesSelection: Int = 0
    var restPickerSecondsSelection: Int = 0
    var restBeforeSetIdToSec: [String: Int] = [:]
    var onStartRest: ((Int) -> Void)?

    /// Handed the set that was just logged. Smart progression uses it to re-suggest the sets of
    /// this exercise that are still to come.
    var onSetCompleted: (@MainActor (WorkoutSetModel, WorkoutExerciseModel) -> Void)?
    /// See `SetTrackerRowDelegate.onLogSet`.
    var onLogSet: (@MainActor (String, Int?) -> Void)?
    var onCustomRestChanged: (@MainActor (String, Int?) -> Void)?

    var previousLookup: [PreviousSetKey: WorkoutSetModel] = [:]

    /// The weight and reps keyboards for this row.
    let keyboard = SetKeyboardPresenter()
    var defaultRestDurationSeconds: Int {
        interactor.workoutSettings.defaultRestDurationSeconds
    }

    init(interactor: SetTrackerRowInteractor, router: SetTrackerRowRouter) {
        self.interactor = interactor
        self.router = router
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
        let weightKg: Double?
        switch subKind {
        case .drop:
            let unit = getUnitPreference(for: current).weightUnit
            let step = WeightStepper.steps(for: current, profile: interactor.workoutGymProfile, unit: unit)
            weightKg = ActiveWorkout.dropWeightKg(from: parent.weightKg, step: step, unit: unit)
        case .mini:
            weightKg = parent.weightKg
        }
        let sets = ActiveWorkout.addingSubSet(subKind, to: setId, in: current.sets, id: UUID().uuidString, weightKg: weightKg)
        withReducedMotionAnimation(.standard) {
            exercise.wrappedValue.sets = sets
        }
        interactor.playHaptic(option: .selection)
    }
    
    func onSetComplete(_ exercise: WorkoutExerciseModel, _ set: Binding<WorkoutSetModel>) {
        if set.wrappedValue.completedAt == nil, let onLogSet {
            onLogSet(set.wrappedValue.id, restBeforeSetIdToSec[set.wrappedValue.id])
        } else if set.wrappedValue.completedAt == nil {
            guard validateSetData(trackingMode: exercise.trackingMode, set: set.wrappedValue, isAssisted: isAssisted(exercise)) else {
                interactor.playHaptic(option: .error)
                return
            }
            set.wrappedValue.completedAt = Date()
            interactor.playHaptic(option: .success)
            let useRestTimers = interactor.workoutSettings.useRestTimers
            let duration = restAfterCompleting(set.wrappedValue, in: exercise)
            interactor.trackEvent(event: Event.setCompleted(
                setId: set.wrappedValue.id,
                exerciseId: exercise.id,
                useRestTimers: useRestTimers,
                restDurationSeconds: duration ?? 0,
                onStartRestIsNil: onStartRest == nil
            ))
            if useRestTimers, let duration {
                onStartRest?(duration)
            }
            // Off by default. With it on, finishing a set re-suggests the ones still to come.
            if interactor.workoutSettings.smartProgressionApplyInSession {
                onSetCompleted?(set.wrappedValue, exercise)
            }
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
        restPickerTargetSetId = setId
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

    func onWarmupSetHelpPressed() {
        // A system alert now, which dismisses itself.
        router.showWarmupSetInfoModal { }
    }

    /// Read from `ExerciseUnitPreferenceManager` every time. Each presenter used to keep its own
    /// copy, and a row's copy outlived a switch to pounds: the header said lb while the keypad
    /// still converted from kg, so a typed 50 lb was stored as 50 kg.
    func getUnitPreference(for exercise: WorkoutExerciseModel) -> (weightUnit: ExerciseWeightUnit, distanceUnit: ExerciseDistanceUnit) {
        let preference = interactor.getPreference(templateId: exercise.templateId)
        return (weightUnit: preference.weightUnit, distanceUnit: preference.distanceUnit)
    }

    func validateSetData(trackingMode: TrackingMode, set: WorkoutSetModel, isAssisted: Bool = false) -> Bool {
        guard let problem = SetValidation.problem(with: set, trackingMode: trackingMode, isAssisted: isAssisted) else { return true }
        router.showSimpleAlert(title: String(localized: "Unable to Log Set"), subtitle: problem)
        return false
    }

    /// See `SetValidation.problem(with:trackingMode:isAssisted:)`.
    static func problem(with set: WorkoutSetModel, trackingMode: TrackingMode, isAssisted: Bool = false) -> String? {
        SetValidation.problem(with: set, trackingMode: trackingMode, isAssisted: isAssisted)
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

/// The line under the set being logged on a bar. `nearestKg` is set when the weight cannot be
/// loaded, and a tap uses it.
struct PlateSummary: Equatable {
    let text: String
    let nearestKg: Double?
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

    var accessibilityLabel: String {
        self == .completed ? String(localized: "Set completed") : String(localized: "Complete set")
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
        keyboard.open(field, set: delegate.set, context: keyboardContext(delegate: delegate))
    }

    func keyboardContext(delegate: SetTrackerRowDelegate) -> SetKeyboardContext {
        let exercise = delegate.exercise.wrappedValue
        let set = delegate.set.wrappedValue
        let units = getUnitPreference(for: exercise)
        let unit = units.weightUnit
        let lastSet = exercise.sets.firstIndex { $0.id == set.id }.flatMap { $0 > 0 ? exercise.sets[$0 - 1] : nil }
        let target = set.isWarmup ? nil : exercise.setTargets.first { $0.setNumber == exercise.workingSetNumber(for: set) }
        // An assisted machine steps below zero, and never above it when the exercise cannot be loaded.
        let library = interactor.allExercises.first { $0.id == exercise.templateId }
        let step = WeightStepper.steps(for: exercise, profile: interactor.workoutGymProfile, unit: unit)
        return SetKeyboardContext(
            unit: unit,
            step: library?.isAssisted == true ? step.assisted(bodyweightOnly: library?.isBodyweight == true) : step,
            distanceUnit: units.distanceUnit,
            fields: SetKeyboardField.fields(for: set, trackingMode: exercise.trackingMode),
            showsEffort: interactor.workoutSettings.rirTracking,
            lastSetWeightKg: lastSet?.weightKg,
            lastSetReps: lastSet?.reps,
            previousSessionWeightKg: delegate.lastSet?.weightKg,
            targetWeightKg: delegate.progressionSuggestion?.weightKg,
            targetMinReps: target?.minReps,
            targetMaxReps: target?.maxReps
        )
    }

    /// "Per side: 20 + 10 + 2.5 kg" under the set being logged on a bar ("Plates: …" on a
    /// single-sleeve machine), from the gym's bar and plates, or "Pin 14 + 2 kg" on a stack with
    /// add-ons. `nil` for anything else or a set with no weight yet.
    func plateSummary(exercise: WorkoutExerciseModel, set: WorkoutSetModel) -> PlateSummary? {
        guard exercise.trackingMode == .weightReps, let weightKg = set.weightKg, weightKg > 0 else { return nil }
        let unit = getUnitPreference(for: exercise).weightUnit
        let step = WeightStepper.steps(for: exercise, profile: interactor.workoutGymProfile, unit: unit)
        let total = (UnitConversion.convertWeight(weightKg, to: unit) * 1000).rounded() / 1000
        if step.stack != nil {
            return step.stackText(total: total, unit: unit).map { PlateSummary(text: $0, nearestKg: nil) }
        }
        guard step.isPlateLoaded, let bar = step.baseWeight else { return nil }
        switch PlateCalculator.load(total: total, bar: bar, plates: step.plates, sleeves: step.sleeves) {
        case .loadable(let perSide):
            return PlateSummary(text: step.plateText(perSide, unit: unit), nearestKg: nil)
        case .notLoadable:
            let nearest = PlateCalculator.nearestLoadable(total: total, bar: bar, plates: step.plates, sleeves: step.sleeves)
            return PlateSummary(
                text: String(localized: "Not loadable. Use \(WeightStepper.format(nearest)) \(unit.abbreviation)"),
                nearestKg: UnitConversion.convertWeightToKg(nearest, from: unit)
            )
        }
    }
}

extension SetTrackerRowPresenter {
    
    enum Event: LoggableEvent {
        /// Every set logged, from a row, the set keyboard or the tracker's log button, which
        /// `source` tells apart.
        case setCompleted(setId: String, exerciseId: String, useRestTimers: Bool, restDurationSeconds: Int, onStartRestIsNil: Bool, source: String = "row")

        var eventName: String {
            switch self {
            case .setCompleted:             return "SetTrackerRow_SetCompleted"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .setCompleted(let setId, let exerciseId, let useRestTimers, let restDurationSeconds, let onStartRestIsNil, let source):
                return [
                    "source": source,
                    "set_id": setId,
                    "exercise_id": exerciseId,
                    "use_rest_timers": useRestTimers,
                    "rest_duration_seconds": restDurationSeconds,
                    "on_start_rest_is_nil": onStartRestIsNil
                ]
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
