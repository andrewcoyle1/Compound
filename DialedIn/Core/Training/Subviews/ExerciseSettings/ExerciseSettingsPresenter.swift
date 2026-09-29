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

    var weightsSubtitle: String {
        "\(unitPreference.weightUnit.displayName) · \(unitPreference.distanceUnit.displayName)"
    }

    var restSubtitle: String {
        if let override = restOverride {
            let mins = override / 60
            let secs = override % 60
            return String(localized: "Custom (\(String(describing: mins))m \(String(format: "%02d", secs))s)")
        }
        let defaultSecs = interactor.workoutSettings.defaultRestDurationSeconds
        return String(localized: "Default (\(String(describing: defaultSecs))s)")
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
        guard settings.restBetweenSideSets else { return "Off" }
        let percent = Int((settings.sideSetRestScaling * 100).rounded())
        return String(localized: "\(String(describing: percent))% of the rest timer")
    }

    var noteSubtitle: String {
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "None" }
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

    func onWeightsPressed() {
        router.showAlert(
            title: String(localized: "Weight Unit"),
            subtitle: String(localized: "Select unit for '\(exercise.name)'"),
            buttons: {
                AnyView(
                    VStack(spacing: 8) {
                        ForEach(ExerciseWeightUnit.allCases, id: \.self) { unit in
                            Button(unit.displayName) {
                                self.onSelectWeightUnit(unit)
                            }
                        }
                        Button("Cancel", role: .cancel) { }
                    }
                )
            }
        )
    }

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
                    try? await self.interactor.setExerciseRestOverride(seconds, for: self.exercise.id)
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
                    try? await self.interactor.setExerciseNote(trimmed.isEmpty ? nil : trimmed, for: self.exercise.id)
                }
            }
        ))
    }
}

extension ExerciseSettingsPresenter {

    enum Event: LoggableEvent {
        case onAppear(delegate: ExerciseSettingsDelegate)
        case onDisappear(delegate: ExerciseSettingsDelegate)

        var eventName: String {
            switch self {
            case .onAppear:     return "ExerciseSettingsView_Appear"
            case .onDisappear:  return "ExerciseSettingsView_Disappear"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .onAppear(delegate: let delegate), .onDisappear(delegate: let delegate):
                return delegate.eventParameters
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
