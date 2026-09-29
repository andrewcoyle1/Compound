import SwiftUI

@Observable
@MainActor
class SetTrackerRowPresenter {
    
    private let interactor: SetTrackerRowInteractor
    private let router: SetTrackerRowRouter
    
    var exerciseUnitPreferences: [String: (weightUnit: ExerciseWeightUnit, distanceUnit: ExerciseDistanceUnit)] = [:]
    var restPickerTargetSetId: String?
    var restPickerMinutesSelection: Int = 0
    var restPickerSecondsSelection: Int = 0
    var restBeforeSetIdToSec: [String: Int] = [:]
    var onStartRest: ((Int) -> Void)?

    /// Handed the set that was just logged. Smart progression uses it to re-suggest the sets of
    /// this exercise that are still to come.
    var onSetCompleted: (@MainActor (WorkoutSetModel, WorkoutExerciseModel) -> Void)?

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
    
    func onViewAppear(delegate: SetTrackerRowDelegate) {
        interactor.trackScreenEvent(event: Event.onAppear(delegate: delegate))
    }
    
    func onViewDisappear(delegate: SetTrackerRowDelegate) {
        interactor.trackEvent(event: Event.onDisappear(delegate: delegate))
    }
    
    /// A left set and its right partner are one set, so swiping either away removes both — a
    /// surviving half would number and rest as a set of its own.
    func deleteSet(setId: String, exercise: Binding<WorkoutExerciseModel>) {
        let removing = Set(exercise.wrappedValue.sets.pairedSetIds(for: setId))
        guard !removing.isEmpty else { return }
        exercise.wrappedValue.sets.removeAll(where: { removing.contains($0.id) })
    }
    
    func onSetComplete(_ exercise: WorkoutExerciseModel, _ set: Binding<WorkoutSetModel>) {
        if set.wrappedValue.completedAt == nil, validateSetData(trackingMode: exercise.trackingMode, set: set.wrappedValue) {
            set.wrappedValue.completedAt = Date()
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
            exerciseTypeRawValue: interactor.allExercises.first(where: { $0.id == exercise.templateId })?.type?.rawValue
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
                self.router.dismissModal()
            },
            secondaryButtonAction: { [weak self] in self?.router.dismissModal() },
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
    }

    func onWarmupSetHelpPressed() {
        router.showWarmupSetInfoModal {
            self.router.dismissModal()
        }
    }

    func getUnitPreference(for exercise: WorkoutExerciseModel) -> (weightUnit: ExerciseWeightUnit, distanceUnit: ExerciseDistanceUnit) {
        let templateId: String = exercise.templateId
        if let cached = exerciseUnitPreferences[templateId] {
            return cached
        }
        let preference = interactor.getPreference(templateId: templateId)
        let result = (weightUnit: preference.weightUnit, distanceUnit: preference.distanceUnit)
        exerciseUnitPreferences[templateId] = result
        return result
    }

    func validateSetData(trackingMode: TrackingMode, set: WorkoutSetModel) -> Bool {
        switch trackingMode {
        case .weightReps:
            if let weight = set.weightKg, weight < 0 {
                router.showSimpleAlert(title: String(localized: "Invalid Set Data"), subtitle: String(localized: "Weight must be a non-negative number"))
                return false
            }
            guard let reps = set.reps, reps > 0 else {
                router.showSimpleAlert(title: String(localized: "Invalid Set Data"), subtitle: String(localized: "Reps must be a positive number"))
                return false
            }
            return true
        case .repsOnly:
            guard let reps = set.reps, reps > 0 else {
                router.showSimpleAlert(title: String(localized: "Invalid Set Data"), subtitle: String(localized: "Reps must be a positive number"))
                return false
            }
            return true
        case .timeOnly:
            guard let duration = set.durationSec, duration > 0 else {
                router.showSimpleAlert(title: String(localized: "Invalid Set Data"), subtitle: String(localized: "Duration must be a positive time"))
                return false
            }
            return true
        case .distanceTime:
            guard let distance = set.distanceMeters, distance > 0 else {
                router.showSimpleAlert(title: String(localized: "Invalid Set Data"), subtitle: String(localized: "Distance must be a positive number"))
                return false
            }
            guard let duration = set.durationSec, duration > 0 else {
                router.showSimpleAlert(title: String(localized: "Invalid Set Data"), subtitle: String(localized: "Duration must be a positive time"))
                return false
            }
            return true
        }
    }

    func canComplete(trackingMode: TrackingMode, set: WorkoutSetModel) -> Bool {
        switch trackingMode {
        case .weightReps:
            let hasValidWeight = set.weightKg == nil || set.weightKg! >= 0
            let hasValidReps = set.reps != nil && set.reps! > 0
            return hasValidWeight && hasValidReps
        case .repsOnly:
            return set.reps != nil && set.reps! > 0
        case .timeOnly:
            return set.durationSec != nil && set.durationSec! > 0
        case .distanceTime:
            let hasValidDistance = set.distanceMeters != nil && set.distanceMeters! > 0
            let hasValidTime = set.durationSec != nil && set.durationSec! > 0
            return hasValidDistance && hasValidTime
        }
    }

    func buttonColor(set: WorkoutSetModel, canComplete: Bool) -> Color {
        if set.completedAt != nil {
            return .green
        } else if canComplete {
            return .secondary
        } else {
            return .secondary.opacity(0.3)
        }
    }
}

// MARK: - Keyboard

extension SetTrackerRowPresenter {

    /// A weight or reps field took focus: open its keyboard on what this set and exercise allow.
    func onKeyboardFieldBegan(_ field: SetKeyboardField, delegate: SetTrackerRowDelegate) {
        keyboard.onOfferCompletion = { [weak self] in self?.offerCompletion(delegate: delegate) }
        keyboard.open(field, set: delegate.set, context: keyboardContext(delegate: delegate))
    }

    func keyboardContext(delegate: SetTrackerRowDelegate) -> SetKeyboardContext {
        let exercise = delegate.exercise.wrappedValue
        let set = delegate.set.wrappedValue
        let unit = getUnitPreference(for: exercise).weightUnit
        let lastSet = exercise.sets.firstIndex { $0.id == set.id }.flatMap { $0 > 0 ? exercise.sets[$0 - 1] : nil }
        let target = set.isWarmup ? nil : exercise.setTargets.first { $0.setNumber == exercise.workingSetNumber(for: set) }
        return SetKeyboardContext(
            unit: unit,
            step: WeightStepper.steps(for: exercise, profile: interactor.favouriteGymProfile, unit: unit),
            tracksWeight: exercise.trackingMode == .weightReps,
            showsEffort: interactor.workoutSettings.rirTracking,
            lastSetWeightKg: lastSet?.weightKg,
            lastSetReps: lastSet?.reps,
            previousSessionWeightKg: delegate.lastSet?.weightKg,
            targetWeightKg: delegate.progressionSuggestion?.weightKg,
            targetMinReps: target?.minReps,
            targetMaxReps: target?.maxReps
        )
    }

    /// Done on a set that is ready to log offers the same action as the row's circle.
    private func offerCompletion(delegate: SetTrackerRowDelegate) {
        let exercise = delegate.exercise.wrappedValue
        let set = delegate.set
        let complete: @MainActor () -> Void = { [weak self] in self?.onSetComplete(exercise, set) }
        interactor.trackEvent(event: Event.keyboardOfferedCompletion)
        router.showAlert(title: String(localized: "Complete Set?"), subtitle: nil) {
            AnyView(VStack(spacing: 8) {
                Button("Not Yet", role: .cancel) { }
                Button("Complete Set") { complete() }
            })
        }
    }
}

extension SetTrackerRowPresenter {
    
    enum Event: LoggableEvent {
        case onAppear(delegate: SetTrackerRowDelegate)
        case onDisappear(delegate: SetTrackerRowDelegate)
        case setCompleted(setId: String, exerciseId: String, useRestTimers: Bool, restDurationSeconds: Int, onStartRestIsNil: Bool)
        case keyboardOfferedCompletion

        var eventName: String {
            switch self {
            case .onAppear:                 return "SetTrackerRowView_Appear"
            case .onDisappear:              return "SetTrackerRowView_Disappear"
            case .setCompleted:             return "SetTrackerRow_SetCompleted"
            case .keyboardOfferedCompletion: return "SetTrackerRow_Keyboard_OfferedCompletion"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .onAppear(delegate: let delegate), .onDisappear(delegate: let delegate):
                return delegate.eventParameters
            case .setCompleted(let setId, let exerciseId, let useRestTimers, let restDurationSeconds, let onStartRestIsNil):
                return [
                    "set_id": setId,
                    "exercise_id": exerciseId,
                    "use_rest_timers": useRestTimers,
                    "rest_duration_seconds": restDurationSeconds,
                    "on_start_rest_is_nil": onStartRestIsNil
                ]
            case .keyboardOfferedCompletion:
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
