import SwiftUI

@Observable
@MainActor
class ExerciseSettingsPresenter {

    private let interactor: ExerciseSettingsInteractor
    private let router: ExerciseSettingsRouter
    private let exercise: ExerciseModel

    private(set) var unitPreference: ExerciseUnitPreference
    var note: String
    private(set) var restOverride: Int?

    var restPickerMinutes: Int = 0
    var restPickerSeconds: Int = 0

    init(interactor: ExerciseSettingsInteractor, router: ExerciseSettingsRouter, exercise: ExerciseModel) {
        self.interactor = interactor
        self.router = router
        self.exercise = exercise
        self.unitPreference = interactor.getPreference(templateId: exercise.id)
        self.note = interactor.exerciseNote(for: exercise.id) ?? ""
        self.restOverride = interactor.exerciseRestOverride(for: exercise.id)
    }

    // MARK: - Computed Subtitles

    var restSubtitle: String {
        if let override = restOverride {
            return String(localized: "Custom (\(Format.duration(TimeInterval(override))))")
        }
        let defaultSecs = interactor.workoutSettings.defaultRestDurationSeconds
        return String(localized: "Default (\(Format.duration(TimeInterval(defaultSecs))))")
    }

    /// Whether this exercise is worked one limb at a time, which is what decides if the
    /// left/right rest row means anything here. Derived from the metrics it is tracked by rather
    /// than `laterality`, which almost every exercise leaves empty.
    var isPerSide: Bool {
        WorkoutSessionModel.isPerSide(exercise)
    }

    /// What currently happens between the two halves of a set. The rest itself is one setting for
    /// the whole app rather than a per-exercise override, so this reports it and the row opens the
    /// screen that owns it.
    var sideSetRestSubtitle: String {
        let settings = interactor.workoutSettings
        guard settings.restBetweenSideSets else { return String(localized: "Off") }
        let percent = Int((settings.sideSetRestScaling * 100).rounded())
        return String(localized: "\(String(describing: percent))% of the rest timer")
    }

    var noteSubtitle: String {
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return String(localized: "None") }
        return trimmed.components(separatedBy: "\n").first ?? trimmed
    }

    // MARK: - Lifecycle

    func onViewAppear(delegate: ExerciseSettingsDelegate) {
        interactor.trackScreenEvent(event: Event.onAppear(delegate: delegate))
    }

    func onViewDisappear(delegate: ExerciseSettingsDelegate) {
        interactor.trackEvent(event: Event.onDisappear(delegate: delegate))
    }

    // MARK: - Actions

    func onInfoPressed() {
        router.showExerciseModelDetailView(delegate: ExerciseModelDetailDelegate(exerciseModel: exercise))
    }

    /// The units are pickers in their rows. Weight used to open an alert listing the units as
    /// buttons, and distance could not be changed at all.
    func onSelectWeightUnit(_ unit: ExerciseWeightUnit) {
        interactor.setWeightUnit(unit, for: exercise.id)
        unitPreference = ExerciseUnitPreference(
            exerciseModelId: exercise.id,
            weightUnit: unit,
            distanceUnit: unitPreference.distanceUnit
        )
    }

    func onSelectDistanceUnit(_ unit: ExerciseDistanceUnit) {
        interactor.setDistanceUnit(unit, for: exercise.id)
        unitPreference = ExerciseUnitPreference(
            exerciseModelId: exercise.id,
            weightUnit: unitPreference.weightUnit,
            distanceUnit: unit
        )
    }

    func onRestTimerPressed() {
        if let override = restOverride {
            restPickerMinutes = override / 60
            restPickerSeconds = override % 60
        } else {
            restPickerMinutes = 0
            restPickerSeconds = 0
        }
        router.showRestModal(
            primaryButtonAction: { [weak self] in
                guard let self else { return }
                let total = self.restPickerMinutes * 60 + self.restPickerSeconds
                let seconds = total > 0 ? total : nil
                Task {
                    do {
                        try await self.interactor.setExerciseRestOverride(seconds, for: self.exercise.id)
                    } catch {
                        self.interactor.trackEvent(event: Event.saveRestOverrideFail(error: error))
                    }
                    self.restOverride = seconds
                }
                self.router.dismissModal()
            },
            secondaryButtonAction: { [weak self] in self?.router.dismissModal() },
            minutesSelection: Binding(
                get: { self.restPickerMinutes },
                set: { self.restPickerMinutes = $0 }
            ),
            secondsSelection: Binding(
                get: { self.restPickerSeconds },
                set: { self.restPickerSeconds = $0 }
            )
        )
    }

    func onSideSetRestPressed() {
        router.showRestTimerSettingsView(delegate: RestTimerSettingsDelegate())
    }

    func onNotePressed() {
        router.showWorkoutNotesView(delegate: WorkoutNotesDelegate(
            notes: Binding(
                get: { self.note },
                set: { self.note = $0 }
            ),
            onSave: { [weak self] in
                guard let self else { return }
                let trimmed = self.note.trimmingCharacters(in: .whitespacesAndNewlines)
                Task {
                    do {
                        try await self.interactor.setExerciseNote(trimmed.isEmpty ? nil : trimmed, for: self.exercise.id)
                    } catch {
                        self.interactor.trackEvent(event: Event.saveNoteFail(error: error))
                    }
                }
            }
        ))
    }
}

extension ExerciseSettingsPresenter {

    enum Event: LoggableEvent {
        case onAppear(delegate: ExerciseSettingsDelegate)
        case onDisappear(delegate: ExerciseSettingsDelegate)
        case saveRestOverrideFail(error: Error)
        case saveNoteFail(error: Error)

        var eventName: String {
            switch self {
            case .onAppear:             return "ExerciseSettingsView_Appear"
            case .onDisappear:          return "ExerciseSettingsView_Disappear"
            case .saveRestOverrideFail: return "ExerciseSettingsView_SaveRestOverride_Fail"
            case .saveNoteFail:         return "ExerciseSettingsView_SaveNote_Fail"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .onAppear(delegate: let delegate), .onDisappear(delegate: let delegate):
                return delegate.eventParameters
            case .saveRestOverrideFail(error: let error), .saveNoteFail(error: let error):
                return error.eventParameters
            }
        }

        var type: LogType {
            switch self {
            case .saveRestOverrideFail, .saveNoteFail:
                return .warning
            default:
                return .analytic
            }
        }
    }
}
