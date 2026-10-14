//
//  SetTrackerPresenter.swift
//  Compound
//
//  Created by Andrew Coyle on 02/03/2026.
//

import SwiftUI

@Observable
@MainActor
class SetTrackerPresenter {
    private let interactor: SetTrackerInteractor
    private let router: SetTrackerRouter

    /// The Last/Auto column's choice in `UserDefaults`: Last session by default; Auto shows smart
    /// progression's suggestion for each set instead. Kept on the device, so the column a user
    /// switched to is the one they get next time.
    static let showAutoRangesKey = "SetTracker.showsSuggestions"
    
    init(interactor: SetTrackerInteractor, router: SetTrackerRouter) {
        self.interactor = interactor
        self.router = router
    }

    func onExerciseEquipmentPressed(_ exercise: Binding<WorkoutExerciseModel>) {
        interactor.trackEvent(event: Event.equipmentOpened)
        // The new equipment's unit, and the sets still to do on weights it makes. The tracker
        // reloads its suggestions for it (`handleWorkoutSessionChange`).
        let refit = { [weak self] (variationId: String?, gym: GymProfileModel?) in
            guard let self else { return }
            var updated = exercise.wrappedValue
            updated.chosenVariationId = variationId
            updated.refitLoad(
                library: updated.libraryModel(in: self.interactor.allExercises),
                gym: gym,
                preference: self.interactor.getPreference(templateId: updated.templateId)
            )
            exercise.wrappedValue = updated
        }
        var delegate = WorkoutExerciseEquipmentSheetDelegate(exercise: exercise) { [weak self] variationId in
            guard let self, exercise.wrappedValue.chosenVariationId != variationId else { return }
            refit(variationId, self.interactor.workoutGymProfile)
        }
        // The equipment itself edited: the same refit, on the gym as saved.
        delegate.onGymEdited = { gym in refit(exercise.wrappedValue.chosenVariationId, gym) }
        router.showWorkoutExerciseEquipmentSheetView(delegate: delegate)
    }
    
    func onExerciseSettingsPressed(exercise: WorkoutExerciseModel) {
        guard let exerciseModel = exercise.libraryModel(in: interactor.allExercises) else { return }
        interactor.trackEvent(event: Event.exerciseSettingsOpened)
        router.showExerciseSettingsView(delegate: ExerciseSettingsDelegate(exercise: exerciseModel))
    }

    func deleteExercise(_ exercise: Binding<WorkoutExerciseModel>, onDelete: @escaping @MainActor () -> Void) {
        let name = exercise.wrappedValue.name
        router.showAlert(title: String(localized: "Delete Exercise?"), subtitle: String(localized: "Remove '\(name)' from this workout?")) {
            AnyView(VStack(spacing: Spacing.s) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) { onDelete() }
            })
        }
    }

    func onTargetsPressed(_ exercise: Binding<WorkoutExerciseModel>) {
        guard let model = exercise.wrappedValue.libraryModel(in: interactor.allExercises) else { return }
        interactor.trackEvent(event: Event.targetsOpened)
        let adapted = Binding<WorkoutTemplateExercise>(
            get: { WorkoutTemplateExercise(exercise: model, setTargets: exercise.wrappedValue.setTargets, setRestTimers: false) },
            set: { exercise.wrappedValue.setTargets = $0.setTargets }
        )
        router.showSetTargetView(delegate: SetTargetDelegate(exercise: adapted))
    }

    /// The live tracker passes `onSwap`, and the swap is its to make: the logged sets stay with the
    /// exercise they were done on (`WorkoutTrackerPresenter.insertSwappedExercise`).
    ///
    /// Without it, as when a finished workout is corrected, the exercise is swapped in place. Logged
    /// sets move to the replacement when it is measured the same way, so a swap keeps what was done.
    /// When it is not, they cannot, and the person is asked before they go.
    func onSwapPressed(_ exercise: Binding<WorkoutExerciseModel>, onSwap: (@MainActor (ExerciseModel) -> Void)? = nil) {
        interactor.trackEvent(event: Event.swapOpened)
        router.showSwapExercisePickerView(alternativeIds: exercise.wrappedValue.substituteExerciseIds) { [weak self] newExercise in
            guard let self else { return }
            if let onSwap { return onSwap(newExercise) }
            let current = exercise.wrappedValue
            let hasLoggedSets = current.sets.contains { $0.completedAt != nil }
            let measuredAlike = current.trackingMode == WorkoutSessionModel.trackingMode(for: newExercise)
                && current.isPerSide == WorkoutSessionModel.isPerSide(newExercise)
            guard hasLoggedSets, !measuredAlike else {
                return self.swap(exercise, to: newExercise, keepingLoggedSets: hasLoggedSets)
            }
            self.router.showConfirmationDialog(
                title: String(localized: "Discard Logged Sets?"),
                subtitle: String(localized: "\(newExercise.name) is measured differently, so the sets logged for \(current.name) can't move to it."),
                buttons: {
                    AnyView(VStack(spacing: Spacing.s) {
                        Button("Swap and Discard Sets", role: .destructive) {
                            self.swap(exercise, to: newExercise, keepingLoggedSets: false)
                        }
                        Button("Cancel", role: .cancel) { }
                    })
                }
            )
        }
    }

    /// The sets not yet logged are replaced by fresh ones, as many working sets as there were open
    /// (three when nothing was logged), so a swap leaves the workout the same length. An open
    /// warm-up is not a working set and does not become one.
    func swap(_ exercise: Binding<WorkoutExerciseModel>, to newExercise: ExerciseModel, keepingLoggedSets: Bool) {
        guard let userId = interactor.userId else { return }
        let newMode = WorkoutSessionModel.trackingMode(for: newExercise)
        let logged = keepingLoggedSets ? exercise.wrappedValue.sets.filter { $0.completedAt != nil } : []
        let openCount = exercise.wrappedValue.sets.filter { $0.completedAt == nil && !$0.isWarmup }.pairedSetCount
        let fresh = logged.isEmpty || openCount > 0
            ? WorkoutSessionModel.defaultSets(
                trackingMode: newMode,
                authorId: userId,
                targetCount: logged.isEmpty ? 3 : openCount,
                perSide: WorkoutSessionModel.isPerSide(newExercise)
            )
            : []
        var sets = logged + fresh
        for index in sets.indices { sets[index].index = index + 1 }
        // Kept split if it was, so the fresh rows match the logged pairs above them.
        if exercise.wrappedValue.isSplit && !logged.isEmpty { sets = sets.splittingSides() }

        var updated = exercise.wrappedValue
        updated.templateId = newExercise.id
        updated.name = newExercise.name
        updated.trackingMode = newMode
        updated.imageName = Constants.exerciseImageName(for: newExercise)
        updated.sets = sets
        updated.setTargets = [SetTarget.standard(setNumber: 1)]
        updated.takeLoad(from: newExercise, gym: interactor.workoutGymProfile, preference: interactor.getPreference(templateId: newExercise.id))
        exercise.wrappedValue = updated
    }

    func onSupersetPressed(
        exercise: Binding<WorkoutExerciseModel>,
        allWorkoutExercises: [WorkoutExerciseModel],
        onSetSupersetGroup: @MainActor @escaping (String, String?) -> Void
    ) {
        let current = exercise.wrappedValue
        // Remove from existing group
        if let groupId = current.supersetGroupId {
            exercise.wrappedValue.supersetGroupId = nil
            let remaining = allWorkoutExercises.filter { $0.supersetGroupId == groupId && $0.id != current.id }
            // If only 1 remains, dissolve — a solo exercise can't be a superset
            if remaining.count == 1, let lastId = remaining.first?.id {
                onSetSupersetGroup(lastId, nil)
            }
            return
        }
        // No group — show all other exercises to pair with
        let available = allWorkoutExercises.filter { $0.id != current.id }
        guard !available.isEmpty else {
            router.showSimpleAlert(title: String(localized: "No Exercises Available"), subtitle: String(localized: "Add more exercises to create a superset or circuit."))
            return
        }
        router.showAlert(title: String(localized: "Add to Group"), subtitle: String(localized: "Pair '\(current.name)' with:")) {
            AnyView(VStack(spacing: Spacing.s) {
                ForEach(available, id: \.id) { partner in
                    let partnerGroupId = partner.supersetGroupId
                    let partnerId = partner.id
                    Button(partner.name) {
                        if let existingGroupId = partnerGroupId {
                            // Join the partner's existing group (builds a circuit)
                            exercise.wrappedValue.supersetGroupId = existingGroupId
                        } else {
                            // Create a new pair
                            let newGroupId = UUID().uuidString
                            exercise.wrappedValue.supersetGroupId = newGroupId
                            onSetSupersetGroup(partnerId, newGroupId)
                        }
                    }
                }
                Button("Cancel", role: .cancel) {}
            })
        }
    }

    /// Read from `ExerciseUnitPreferenceManager` every time. Each presenter used to keep its own
    /// copy, and a row's copy outlived a switch to pounds: the header said lb while the keypad
    /// still converted from kg, so a typed 50 lb was stored as 50 kg.
    func getUnitPreference(for exercise: WorkoutExerciseModel) -> (weightUnit: ExerciseWeightUnit, distanceUnit: ExerciseDistanceUnit) {
        let units = exercise.units(interactor.getPreference(templateId: exercise.templateId))
        return (weightUnit: units.weightUnit, distanceUnit: units.distanceUnit)
    }

    /// Whether the exercise logs the weight of each side, as a dumbbell in each hand is
    /// (`TrackableExerciseMetric.weightPerSide` and its variants): its weight column reads "Kg/side".
    func tracksWeightPerSide(_ exercise: WorkoutExerciseModel) -> Bool {
        let perSide: [TrackableExerciseMetric] = [.weightPerSide, .weightPerSidePersistent, .weightPerSideAssistance]
        let metrics = exercise.libraryModel(in: interactor.allExercises)?.trackableMetrics ?? []
        return exercise.loadsPerSet == 2 || perSide.contains(where: metrics.contains)
    }

    /// "Kg", or "Kg/side" on an exercise that tracks the weight per side.
    func weightColumnTitle(for exercise: WorkoutExerciseModel, unit: ExerciseWeightUnit) -> String {
        let title = unit.abbreviation.capitalized
        return tracksWeightPerSide(exercise) ? String(localized: "\(title)/side") : title
    }

    func weightColumnLabel(for exercise: WorkoutExerciseModel, unit: ExerciseWeightUnit) -> String {
        tracksWeightPerSide(exercise)
            ? String(localized: "Weight unit, \(unit.displayName) per side")
            : String(localized: "Weight unit, \(unit.displayName)")
    }

    /// Logs each side as its own row, or both sides as one again. Joining keeps the left side's
    /// figures; the chip that calls this only shows for an exercise worked a side at a time.
    func onSplitSidesPressed(_ exercise: Binding<WorkoutExerciseModel>) {
        let sets = exercise.wrappedValue.sets
        let splitting = !exercise.wrappedValue.isSplit
        exercise.wrappedValue.sets = splitting ? sets.splittingSides() : sets.joiningSides()
        interactor.playHaptic(option: .selection)
        interactor.trackEvent(event: Event.sidesSplit(splitting))
    }

    /// Adds one more set (`WorkoutExerciseModel.addingSet`).
    func addSet(exercise: Binding<WorkoutExerciseModel>) {
        guard let userId = interactor.userId else { return }
        exercise.wrappedValue = exercise.wrappedValue.addingSet(authorId: userId)
        interactor.playHaptic(option: .selection)
        interactor.trackEvent(event: Event.setAdded)
    }

    func updateWeightUnit(_ unit: ExerciseWeightUnit, for exercise: Binding<WorkoutExerciseModel>) {
        let templateId: String = exercise.wrappedValue.templateId
        interactor.setWeightUnit(unit, for: templateId)
        exercise.wrappedValue.weightUnit = unit
        interactor.playHaptic(option: .selection)
        interactor.trackEvent(event: Event.unitChanged(unit: unit.rawValue))
    }

    /// Converts the sets not yet logged into `newUnit`, each to the nearest weight the gym's
    /// equipment can make in it, and makes `newUnit` this exercise's unit. Logged sets are history
    /// and keep what was lifted: 100 kg converted and rounded to 220 lb would be 99.79 kg.
    func convertAndRoundWeights(to newUnit: ExerciseWeightUnit, for exercise: Binding<WorkoutExerciseModel>) {
        // The same rule prefill rounds by: the chosen equipment, mirrored below zero for an
        // assisted exercise, so −30 kg of help stays help rather than snapping to a pin.
        var updated = exercise.wrappedValue
        let rule = WeightRoundingRule(
            exercise: updated.libraryModel(in: interactor.allExercises),
            gymProfile: interactor.workoutGymProfile,
            preferredWeightUnit: newUnit,
            resistanceEquipment: updated.activeVariation?.resistanceEquipment
        )
        for index in updated.sets.indices where updated.sets[index].completedAt == nil {
            updated.sets[index].weightKg = updated.sets[index].weightKg.map(rule.round)
        }
        updated.weightUnit = newUnit
        exercise.wrappedValue = updated
        interactor.setWeightUnit(newUnit, for: updated.templateId)
    }

    /// The unit is a preference on the exercise, not on this workout, so the dialog says so.
    static var unitChangeMessage: String {
        String(localized: "This changes the unit for this exercise everywhere, including future workouts. Convert Values also converts the sets not yet logged.")
    }

    /// Shows a prompt asking whether to just change display unit or convert values
    func promptWeightUnitChange(_ newUnit: ExerciseWeightUnit, for exercise: Binding<WorkoutExerciseModel>) {
        let currentUnit = getUnitPreference(for: exercise.wrappedValue).weightUnit
        guard newUnit != currentUnit else { return }

        router.showConfirmationDialog(
            title: String(localized: "Change Weight Unit"),
            subtitle: Self.unitChangeMessage,
            buttons: {
                AnyView(
                    VStack(spacing: Spacing.s) {
                        Button("Display Only") {
                            self.updateWeightUnit(newUnit, for: exercise)
                        }
                        Button("Convert Values") {
                            self.convertAndRoundWeights(to: newUnit, for: exercise)
                        }
                        Button("Cancel", role: .cancel) { }
                    }
                )
            }
        )
    }

    /// Shows a prompt asking whether to just change display unit or convert values
    func promptDistanceUnitChange(_ newUnit: ExerciseDistanceUnit, for exercise: Binding<WorkoutExerciseModel>) {
        let currentUnit = getUnitPreference(for: exercise.wrappedValue).distanceUnit
        guard newUnit != currentUnit else { return }

        router.showConfirmationDialog(
            title: String(localized: "Change Distance Unit"),
            subtitle: Self.unitChangeMessage,
            buttons: {
                AnyView(
                    VStack(spacing: Spacing.s) {
                        Button("Display Only") {
                            self.updateDistanceUnit(newUnit, for: exercise)
                        }
                        Button("Convert Values") {
                            self.convertAndRoundDistances(to: newUnit, for: exercise)
                        }
                        Button("Cancel", role: .cancel) { }
                    }
                )
            }
        )
    }

    /// As `convertAndRoundWeights`: only the sets not yet logged change.
    func convertAndRoundDistances(to newUnit: ExerciseDistanceUnit, for exercise: Binding<WorkoutExerciseModel>) {
        for set in exercise.sets where set.wrappedValue.completedAt == nil {
            guard let distanceMeters = set.wrappedValue.distanceMeters else { continue }
            let distanceInNewUnit = UnitConversion.convertDistance(distanceMeters, to: newUnit)
            let roundedDistance: Double
            if newUnit == .meters {
                roundedDistance = round(distanceInNewUnit)
            } else {
                roundedDistance = round(distanceInNewUnit * 100) / 100.0
            }
            set.wrappedValue.distanceMeters = UnitConversion.convertDistanceToMeters(roundedDistance, from: newUnit)
        }
        updateDistanceUnit(newUnit, for: exercise)
    }

    func updateDistanceUnit(_ unit: ExerciseDistanceUnit, for exercise: Binding<WorkoutExerciseModel>) {
        let templateId: String = exercise.wrappedValue.templateId
        interactor.setDistanceUnit(unit, for: templateId)
        interactor.playHaptic(option: .selection)
        interactor.trackEvent(event: Event.unitChanged(unit: unit.rawValue))
    }
}

extension SetTrackerPresenter {

    enum Event: LoggableEvent {
        case equipmentOpened
        case exerciseSettingsOpened
        case targetsOpened
        case swapOpened
        case setAdded
        /// True when the sides were split, false when joined again.
        case sidesSplit(Bool)
        case unitChanged(unit: String)

        var eventName: String {
            switch self {
            case .equipmentOpened:          return "SetTracker_Equipment_Opened"
            case .exerciseSettingsOpened:   return "SetTracker_ExerciseSettings_Opened"
            case .targetsOpened:            return "SetTracker_Targets_Opened"
            case .swapOpened:               return "SetTracker_Swap_Opened"
            case .setAdded:                 return "SetTracker_Set_Added"
            case .sidesSplit:               return "SetTracker_Sides_Split"
            case .unitChanged:              return "SetTracker_Unit_Changed"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .sidesSplit(let split): ["split": split]
            case .unitChanged(let unit): ["unit": unit]
            default: nil
            }
        }

        var type: LogType { .analytic }
    }
}
